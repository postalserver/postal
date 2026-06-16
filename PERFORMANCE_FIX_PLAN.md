# Performance Fix Plan - Queue Head-of-Line Blocking

## Date: 2026-01-09
## Session: ses_4606130c7ffe7Gh3xytvH0orNc

## Problem Summary

The Postal mail server experiences periodic slowdowns where messages take 5+ minutes to process instead of the expected <3 minutes. Analysis revealed:

1. **Head-of-line blocking**: With only 2 worker threads processing messages from 41 servers, when one server sends many messages, other servers' messages (including mailflow monitoring) get backed up in the queue.

2. **No fairness in queue selection**: The current `process_queued_messages_job.rb` selects messages with NO ORDER BY clause, meaning MySQL returns them by insertion order (primary key). If Server A queues 50 messages rapidly (IDs 1000-1050), they all get processed before Server B's message (ID 1051).

## Root Cause

From `app/lib/worker/jobs/process_queued_messages_job.rb` line 46-50:
```ruby
def lock_message_for_processing
  QueuedMessage.where(ip_address_id: [nil, @ip_addresses])
               .where(locked_by: nil, locked_at: nil)
               .ready_with_delayed_retry
               .limit(1)  # Only 1 message per poll!
               .update_all(locked_by: @locker, locked_at: @lock_time)
end
```

No ORDER BY = no fairness = head-of-line blocking.

## Solution: 3-Part Fix

### 1. Implement Round-Robin Server Selection
**Goal**: Ensure fair distribution of worker threads across all servers to prevent head-of-line blocking.

**File to modify:** `app/lib/worker/jobs/process_queued_messages_job.rb`

**Changes needed:**

**A. Add instance variable** (in `initialize` method):
```ruby
def initialize(ip_address_ids)
  @ip_addresses = ip_address_ids
  @locker = "#{Process.pid}:#{Thread.current.object_id}"
  @lock_time = nil
  @last_processed_server_id = 0  # ADD THIS LINE
end
```

**B. Replace `lock_message_for_processing` method** (lines 42-50):
```ruby
# Obtain a queued message from the database for processing
# Uses round-robin server selection to prevent head-of-line blocking
#
# @return [void]
def lock_message_for_processing
  # Base query for available messages
  base_query = QueuedMessage.where(ip_address_id: [nil, @ip_addresses])
                            .where(locked_by: nil, locked_at: nil)
                            .ready_with_delayed_retry
  
  # Try to find next server after the last one we processed
  # This implements round-robin fairness across servers
  message_id = base_query
                 .where("server_id > ?", @last_processed_server_id)
                 .order("server_id ASC, id ASC")
                 .limit(1)
                 .pluck(:id)
                 .first
  
  # If no message found from servers after last_processed_server_id, wrap around
  if message_id.nil?
    message_id = base_query
                   .order("server_id ASC, id ASC")
                   .limit(1)
                   .pluck(:id)
                   .first
  end
  
  # Lock the selected message atomically
  if message_id
    result = QueuedMessage.where(id: message_id, locked_by: nil, locked_at: nil)
                          .update_all(locked_by: @locker, locked_at: @lock_time)
    
    # Track which server we just processed for next round
    if result > 0
      server_id = QueuedMessage.where(id: message_id).pluck(:server_id).first
      @last_processed_server_id = server_id if server_id
    end
  end
end
```

**Why this works:**
- Each worker thread cycles through servers in order (1, 2, 3, ... 41, 1, 2, ...)
- If Server A has 50 messages queued and Server B has 1, Server B gets processed every 41st message instead of waiting for all 50
- Prevents monopolization while maintaining simplicity

---

### 2. Add Timing Instrumentation
**Goal**: Add forensic timing data to logs so we can analyze performance issues retroactively.

**File to modify:** `app/lib/message_dequeuer/outgoing_message_processor.rb`

**Add timing wrapper around key operations:**

**A. At the top of the class, add helper method:**
```ruby
def measure_time
  start = Time.now
  result = yield
  elapsed_ms = ((Time.now - start) * 1000).round(2)
  [result, elapsed_ms]
rescue => e
  elapsed_ms = ((Time.now - start) * 1000).round(2)
  raise e
ensure
  @timing_data ||= {}
end
```

**B. Modify the `process` method** (around line 30-60) to add timing:
```ruby
def process
  @timing_data = {
    message_id: @queued_message.message_id,
    server_id: @queued_message.server_id,
    queue_id: @queued_message.id,
    domain: @queued_message.domain,
    start_time: Time.now.utc.iso8601(3)
  }
  
  start_total = Time.now
  
  # Time: Load message from database
  @message, @timing_data[:load_ms] = measure_time do
    load_message
  end
  
  @timing_data[:message_size] = @message&.size || 0
  
  # Time: Inspect message (spam/virus scanning)
  _, @timing_data[:inspect_ms] = measure_time do
    inspect_message
  end
  
  # Time: Add outgoing headers (DKIM signing)
  _, @timing_data[:dkim_ms] = measure_time do
    add_outgoing_headers
  end
  
  # Time: Deliver message (SMTP transmission)
  _, @timing_data[:deliver_ms] = measure_time do
    deliver
  end
  
  @timing_data[:total_ms] = ((Time.now - start_total) * 1000).round(2)
  @timing_data[:status] = "success"
  
  Postal.logger.info "[TIMING] #{@timing_data.to_json}"
  
rescue => e
  @timing_data[:total_ms] = ((Time.now - start_total) * 1000).round(2)
  @timing_data[:status] = "error"
  @timing_data[:error] = e.class.name
  
  Postal.logger.error "[TIMING] #{@timing_data.to_json}"
  raise e
end
```

**What this gives us:**
- JSON-formatted timing logs for every message
- Can grep logs for `[TIMING]` and analyze with jq
- Can correlate message size with DKIM signing time
- Can identify which operation is the bottleneck

**Example log output:**
```json
[TIMING] {"message_id":609676,"server_id":3,"queue_id":7855123,"domain":"edify.press","start_time":"2026-01-09T12:34:56.789Z","load_ms":12.5,"inspect_ms":3.2,"dkim_ms":45.8,"deliver_ms":156.3,"total_ms":234.1,"message_size":5242880,"status":"success"}
```

---

### 3. Increase Worker Threads
**Goal**: Give the system more parallelism to handle bursts and reduce queueing delays.

**File to modify:** User's `/opt/postal/config/postal.yml` on server

**Add this section:**
```yaml
worker:
  threads: 10  # Increase from default of 2 to 10
```

**Also consider increasing database pool sizes:**
```yaml
main_db:
  pool_size: 30  # Was 25, increase to handle more threads

message_db:
  pool_size: 15  # Was 10, increase to handle more threads
```

**Deployment:**
```bash
cd /opt/postal/install
# Edit ../config/postal.yml as shown above
docker-compose restart worker
```

---

## Execution Order

### Phase 1: Code Changes (Local)
1. **Implement round-robin selection** (Task 1)
   - Modify process_queued_messages_job.rb
   - Test with multiple servers to verify fair distribution

2. **Add timing instrumentation** (Task 2)
   - Modify outgoing_message_processor.rb
   - Test that logs contain [TIMING] entries

### Phase 2: Testing
4. **Local testing**
   - Run test suite: `bundle exec rspec`
   - Send test messages through multiple servers
   - Verify timing logs appear correctly
   - Verify round-robin behavior (check logs for different server_ids)

### Phase 3: Deployment
5. **Commit changes**
   - Create descriptive commit message
   - Push to repository

6. **Deploy to production**
   - Pull latest code on server
   - Update postal.yml with worker config (Task 4)
   - Run migrations
   - Restart services: `docker-compose restart`

7. **Monitor**
   - Watch mailflow monitoring for improvements
   - Grep logs for `[TIMING]` to analyze performance
   - Check that different servers are being processed (server_id variety in logs)

---

## Success Metrics

**Before fix:**
- Mailflow messages taking 300-320s (5+ minutes)
- Head-of-line blocking when busy server sends many messages
- Only 2 worker threads

**After fix:**
- Mailflow messages should take <180s (3 minutes)
- Fair distribution across all 41 servers
- 10 worker threads available
- Timing data in logs for forensic analysis

**How to verify:**
```bash
# On server, monitor timing logs
docker logs -f postal_worker_1 | grep TIMING

# Check for round-robin (should see variety of server_ids)
docker logs postal_worker_1 | grep TIMING | jq '.server_id' | sort | uniq -c

# Check average processing times
docker logs postal_worker_1 | grep TIMING | jq '.total_ms' | awk '{sum+=$1; count++} END {print sum/count}'

# Check mailflow specifically (server_id=3)
docker logs postal_worker_1 | grep TIMING | jq 'select(.server_id == 3)'
```

---

## Rollback Plan

If issues occur:

1. **Revert code changes:**
   ```bash
   git revert <commit-hash>
   docker-compose restart
   ```

2. **Reduce worker threads** in postal.yml:
   ```yaml
   worker:
     threads: 2  # Back to default
   ```

3. **Database is safe** - none of these changes alter the schema

---

## Notes for Future Context

- The core issue is NOT DKIM signing speed or attachment size (those are fast)
- The core issue IS queue selection fairness with limited worker threads
- With 41 servers on 2 worker threads, even low volume can cause delays
- Round-robin + more threads should solve 90% of the problem
- Timing logs will help us identify any remaining bottlenecks

---

## Contact/Session Info

- Session ID: ses_4606130c7ffe7Gh3xytvH0orNc
- Session file: `/Users/matt/repo/postal/session-ses_4606.md`
- Server: e1.edify.press
- Database: 10.20.8.7 (MySQL/MariaDB)
- Edify server_id: 3
- Total servers: 41
