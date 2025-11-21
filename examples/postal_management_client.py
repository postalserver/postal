#!/usr/bin/env python3
"""
Postal Management API Client

This client provides automation capabilities for Postal mail server administration.
It supports creating servers, domains, credentials, and webhooks programmatically.

Usage:
    from postal_management_client import PostalManagementClient

    client = PostalManagementClient(
        base_url="https://postal.example.com",
        api_key="your-management-api-key"
    )

    # Full setup for a new mail server
    result = client.full_setup(
        organization="my-org",
        server_name="Server1",
        domain_name="example.com",
        ip_pool_id=1,
        webhook_url="https://api.example.com/bounces"
    )
"""

import requests
import json
import time
from typing import Optional, Dict, List, Any
from dataclasses import dataclass


@dataclass
class DNSRecord:
    """DNS record to be configured"""
    record_type: str
    name: str
    value: str
    purpose: str
    required: bool = True
    priority: Optional[int] = None


class PostalManagementClient:
    """Client for Postal Management API"""

    def __init__(self, base_url: str, api_key: str, timeout: int = 30):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.timeout = timeout
        self.session = requests.Session()
        self.session.headers.update({
            "X-Management-API-Key": api_key,
            "Content-Type": "application/json",
            "Accept": "application/json"
        })

    def _request(self, method: str, endpoint: str, data: Optional[Dict] = None) -> Dict:
        """Make API request"""
        url = f"{self.base_url}/management/api/v1{endpoint}"
        response = self.session.request(
            method=method,
            url=url,
            json=data,
            timeout=self.timeout
        )

        result = response.json()

        if result.get("status") == "error":
            error_data = result.get("data", {})
            raise PostalAPIError(
                code=error_data.get("code", "Unknown"),
                message=error_data.get("message", "Unknown error"),
                errors=error_data.get("errors")
            )

        return result.get("data", {})

    # ============ IP Pools ============

    def get_ip_pools(self) -> List[Dict]:
        """Get all available IP pools"""
        result = self._request("GET", "/ip_pools")
        return result.get("ip_pools", [])

    def get_organization_ip_pools(self, organization: str) -> List[Dict]:
        """Get IP pools available for an organization"""
        result = self._request("GET", f"/organizations/{organization}/ip_pools")
        return result.get("ip_pools", [])

    # ============ Organizations ============

    def list_organizations(self) -> List[Dict]:
        """List all organizations"""
        result = self._request("GET", "/organizations")
        return result.get("organizations", [])

    def get_organization(self, permalink: str) -> Dict:
        """Get organization details"""
        result = self._request("GET", f"/organizations/{permalink}")
        return result.get("organization", {})

    def create_organization(self, name: str, owner_email: str,
                           permalink: Optional[str] = None,
                           time_zone: str = "UTC") -> Dict:
        """Create a new organization"""
        result = self._request("POST", "/organizations", {
            "name": name,
            "owner_email": owner_email,
            "permalink": permalink,
            "time_zone": time_zone
        })
        return result.get("organization", {})

    # ============ Servers ============

    def list_servers(self, organization: Optional[str] = None) -> List[Dict]:
        """List all servers, optionally filtered by organization"""
        params = ""
        if organization:
            params = f"?organization={organization}"
        result = self._request("GET", f"/servers{params}")
        return result.get("servers", [])

    def get_server(self, server_id: str) -> Dict:
        """
        Get server details

        Args:
            server_id: Can be numeric ID or 'org/server' format
        """
        result = self._request("GET", f"/servers/{server_id}")
        return result.get("server", {})

    def create_server(self, organization: str, name: str,
                      ip_pool_id: Optional[int] = None,
                      mode: str = "Live",
                      message_retention_days: int = 2,
                      raw_message_retention_days: int = 2,
                      raw_message_retention_size: int = 12048) -> Dict:
        """
        Create a new server with default settings

        Args:
            organization: Organization permalink
            name: Server name
            ip_pool_id: IP pool ID to use
            mode: "Live" or "Development"
            message_retention_days: Days to keep message metadata
            raw_message_retention_days: Days to keep raw messages
            raw_message_retention_size: Max size in MB for raw messages

        Returns:
            Dict with server info and auto-generated API credentials
        """
        result = self._request("POST", "/servers", {
            "organization": organization,
            "name": name,
            "ip_pool_id": ip_pool_id,
            "mode": mode,
            "message_retention_days": message_retention_days,
            "raw_message_retention_days": raw_message_retention_days,
            "raw_message_retention_size": raw_message_retention_size
        })
        return result

    def update_server(self, server_id: str, **kwargs) -> Dict:
        """Update server settings"""
        result = self._request("PATCH", f"/servers/{server_id}", kwargs)
        return result.get("server", {})

    def delete_server(self, server_id: str) -> Dict:
        """Delete a server"""
        return self._request("DELETE", f"/servers/{server_id}")

    # ============ Domains ============

    def list_domains(self, server_id: str) -> List[Dict]:
        """List all domains for a server"""
        result = self._request("GET", f"/servers/{server_id}/domains")
        return result.get("domains", [])

    def get_domain(self, server_id: str, domain_uuid: str) -> Dict:
        """Get domain details"""
        result = self._request("GET", f"/servers/{server_id}/domains/{domain_uuid}")
        return result.get("domain", {})

    def add_domain(self, server_id: str, name: str,
                   auto_verify: bool = True) -> Dict:
        """
        Add a domain to a server

        Args:
            server_id: Server ID or 'org/server' format
            name: Domain name (e.g., "example.com")
            auto_verify: If True, domain is immediately verified

        Returns:
            Dict with domain info and DNS records to configure
        """
        result = self._request("POST", f"/servers/{server_id}/domains", {
            "name": name,
            "auto_verify": auto_verify
        })
        return result

    def verify_domain(self, server_id: str, domain_uuid: str) -> Dict:
        """Verify domain ownership via DNS TXT record"""
        return self._request("POST", f"/servers/{server_id}/domains/{domain_uuid}/verify")

    def check_domain_dns(self, server_id: str, domain_uuid: str) -> Dict:
        """Check DNS configuration for a domain"""
        return self._request("POST", f"/servers/{server_id}/domains/{domain_uuid}/check_dns")

    def get_domain_dns_records(self, server_id: str, domain_uuid: str) -> Dict:
        """Get all DNS records needed for a domain"""
        return self._request("GET", f"/servers/{server_id}/domains/{domain_uuid}/dns_records")

    def delete_domain(self, server_id: str, domain_uuid: str) -> Dict:
        """Remove a domain from a server"""
        return self._request("DELETE", f"/servers/{server_id}/domains/{domain_uuid}")

    # ============ Credentials ============

    def list_credentials(self, server_id: str) -> List[Dict]:
        """List all credentials for a server"""
        result = self._request("GET", f"/servers/{server_id}/credentials")
        return result.get("credentials", [])

    def create_credential(self, server_id: str, name: str,
                          credential_type: str = "API",
                          hold: bool = False,
                          key: Optional[str] = None) -> Dict:
        """
        Create a new credential

        Args:
            server_id: Server ID or 'org/server' format
            name: Credential name
            credential_type: "API", "SMTP", or "SMTP-IP"
            hold: If True, messages will be held
            key: Required for SMTP-IP type (IP address)

        Returns:
            Dict with credential info including generated key
        """
        result = self._request("POST", f"/servers/{server_id}/credentials", {
            "name": name,
            "type": credential_type,
            "hold": hold,
            "key": key
        })
        return result.get("credential", {})

    def delete_credential(self, server_id: str, credential_uuid: str) -> Dict:
        """Delete a credential"""
        return self._request("DELETE", f"/servers/{server_id}/credentials/{credential_uuid}")

    # ============ Webhooks ============

    def list_webhooks(self, server_id: str) -> List[Dict]:
        """List all webhooks for a server"""
        result = self._request("GET", f"/servers/{server_id}/webhooks")
        return result.get("webhooks", [])

    def create_webhook(self, server_id: str, name: str, url: str,
                       events: Optional[List[str]] = None,
                       all_events: bool = False,
                       enabled: bool = True,
                       sign: bool = True) -> Dict:
        """
        Create a webhook

        Args:
            server_id: Server ID or 'org/server' format
            name: Webhook name
            url: Webhook URL
            events: List of events to subscribe to:
                    - MessageSent
                    - MessageDelayed
                    - MessageDeliveryFailed
                    - MessageHeld
                    - MessageBounced
                    - MessageLinkClicked
                    - MessageLoaded
                    - DomainDNSError
            all_events: If True, receive all events
            enabled: If True, webhook is active
            sign: If True, requests are signed

        Returns:
            Dict with webhook info
        """
        result = self._request("POST", f"/servers/{server_id}/webhooks", {
            "name": name,
            "url": url,
            "events": events,
            "all_events": all_events,
            "enabled": enabled,
            "sign": sign
        })
        return result.get("webhook", {})

    def update_webhook(self, server_id: str, webhook_uuid: str, **kwargs) -> Dict:
        """Update a webhook"""
        result = self._request("PATCH", f"/servers/{server_id}/webhooks/{webhook_uuid}", kwargs)
        return result.get("webhook", {})

    def delete_webhook(self, server_id: str, webhook_uuid: str) -> Dict:
        """Delete a webhook"""
        return self._request("DELETE", f"/servers/{server_id}/webhooks/{webhook_uuid}")

    # ============ Full Setup ============

    def full_setup(self, organization: str, server_name: str, domain_name: str,
                   ip_pool_id: Optional[int] = None,
                   webhook_url: Optional[str] = None,
                   webhook_events: Optional[List[str]] = None,
                   wait_for_dns: bool = False,
                   dns_check_interval: int = 30,
                   dns_check_max_attempts: int = 20) -> Dict:
        """
        Complete server setup with domain, credentials, and webhook

        This performs the full workflow:
        1. Create server with IP pool
        2. Add domain (auto-verified)
        3. Return DNS records to configure
        4. Optionally create webhook for bounces

        Args:
            organization: Organization permalink
            server_name: Name for the new server
            domain_name: Domain to add
            ip_pool_id: IP pool ID to use
            webhook_url: URL for bounce webhook
            webhook_events: Events for webhook (default: bounces only)
            wait_for_dns: If True, wait for DNS to be configured
            dns_check_interval: Seconds between DNS checks
            dns_check_max_attempts: Max DNS check attempts

        Returns:
            Complete setup information including DNS records and credentials
        """
        print(f"Creating server '{server_name}'...")

        # 1. Create server
        server_result = self.create_server(
            organization=organization,
            name=server_name,
            ip_pool_id=ip_pool_id,
            mode="Live",
            message_retention_days=2,
            raw_message_retention_days=2,
            raw_message_retention_size=12048
        )

        server = server_result["server"]
        server_id = server["id"]
        api_key = server_result["credentials"]["api_key"]

        print(f"  Server created: {server['full_permalink']}")
        print(f"  API Key: {api_key}")

        # 2. Add domain
        print(f"Adding domain '{domain_name}'...")
        domain_result = self.add_domain(server_id, domain_name, auto_verify=True)
        domain = domain_result["domain"]

        print(f"  Domain added: {domain['uuid']}")

        # 3. Create webhook if URL provided
        webhook = None
        if webhook_url:
            print(f"Creating webhook...")
            events = webhook_events or ["MessageDeliveryFailed", "MessageBounced"]
            webhook = self.create_webhook(
                server_id=server_id,
                name=domain_name,
                url=webhook_url,
                events=events,
                enabled=True
            )
            print(f"  Webhook created: {webhook['uuid']}")

        # 4. Wait for DNS if requested
        if wait_for_dns:
            print("Waiting for DNS configuration...")
            for attempt in range(dns_check_max_attempts):
                dns_result = self.check_domain_dns(server_id, domain["uuid"])
                if dns_result.get("dns_ok"):
                    print("  DNS configured correctly!")
                    domain = dns_result["domain"]
                    break
                print(f"  DNS check {attempt + 1}/{dns_check_max_attempts} - waiting...")
                time.sleep(dns_check_interval)
            else:
                print("  DNS check timeout - configure records manually")

        # Return complete setup info
        return {
            "server": server,
            "credentials": {
                "api_key": api_key,
                "smtp_host": server.get("organization"),  # postal hostname
                "smtp_port": 25
            },
            "domain": domain,
            "dns_records": domain.get("dns_records", {}),
            "webhook": webhook
        }

    def print_dns_records(self, dns_records: Dict) -> None:
        """Print DNS records in a readable format"""
        print("\n" + "=" * 60)
        print("DNS RECORDS TO CONFIGURE")
        print("=" * 60)

        if "spf" in dns_records:
            spf = dns_records["spf"]
            print(f"\nSPF Record (TXT):")
            print(f"  Name:  {spf['name']}")
            print(f"  Value: {spf['value']}")

        if "dkim" in dns_records:
            dkim = dns_records["dkim"]
            print(f"\nDKIM Record (TXT):")
            print(f"  Name:  {dkim['name']}")
            print(f"  Value: {dkim['value']}")

        if "return_path" in dns_records:
            rp = dns_records["return_path"]
            print(f"\nReturn Path (CNAME):")
            print(f"  Name:  {rp['name']}")
            print(f"  Value: {rp['value']}")

        if "mx" in dns_records:
            mx = dns_records["mx"]
            print(f"\nMX Records (for incoming mail):")
            print(f"  Priority: {mx.get('priority', 10)}")
            for record in mx.get("values", []):
                print(f"  Value: {record}")

        print("=" * 60 + "\n")


class PostalAPIError(Exception):
    """Postal API Error"""

    def __init__(self, code: str, message: str, errors: Optional[Dict] = None):
        self.code = code
        self.message = message
        self.errors = errors
        super().__init__(f"{code}: {message}")


# ============ Example Usage ============

if __name__ == "__main__":
    import os
    import sys

    # Configuration from environment or arguments
    POSTAL_URL = os.environ.get("POSTAL_URL", "https://postal.example.com")
    POSTAL_API_KEY = os.environ.get("POSTAL_MANAGEMENT_API_KEY", "your-api-key")

    # Example usage
    client = PostalManagementClient(POSTAL_URL, POSTAL_API_KEY)

    print("Postal Management API Client")
    print("=" * 40)

    try:
        # List IP pools
        print("\nAvailable IP Pools:")
        pools = client.get_ip_pools()
        for pool in pools:
            print(f"  - {pool['name']} (ID: {pool['id']})")
            for ip in pool.get("ip_addresses", []):
                print(f"      {ip['ip_address']}")

        # Example: Full setup (uncomment to run)
        # result = client.full_setup(
        #     organization="main",
        #     server_name="NewServer",
        #     domain_name="mydomain.com",
        #     ip_pool_id=1,
        #     webhook_url="https://mysite.com/postal/bounces"
        # )
        # client.print_dns_records(result["dns_records"])
        # print(f"API Key for sending: {result['credentials']['api_key']}")

    except PostalAPIError as e:
        print(f"API Error: {e.code} - {e.message}")
        if e.errors:
            print(f"Details: {e.errors}")
        sys.exit(1)
    except requests.exceptions.RequestException as e:
        print(f"Connection Error: {e}")
        sys.exit(1)
