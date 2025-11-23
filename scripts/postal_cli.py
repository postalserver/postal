#!/usr/bin/env python3
"""
Postal Management API CLI Tool

Interactive command-line tool for managing Postal mail server.
Supports adding domains, creating organizations and servers.

Usage:
    python postal_cli.py --url https://postal.example.com --api-key YOUR_API_KEY

    Or set environment variables:
    export POSTAL_URL=https://postal.example.com
    export POSTAL_API_KEY=YOUR_API_KEY
    python postal_cli.py
"""

import argparse
import json
import os
import sys
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError


class PostalAPI:
    """Client for Postal Management API v2"""

    def __init__(self, base_url: str, api_key: str):
        self.base_url = base_url.rstrip('/')
        self.api_key = api_key
        self.api_base = f"{self.base_url}/api/v2/management"

    def _request(self, method: str, endpoint: str, data: dict = None) -> dict:
        """Make an API request"""
        url = f"{self.api_base}/{endpoint.lstrip('/')}"

        headers = {
            'X-Management-API-Key': self.api_key,
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }

        body = json.dumps(data).encode('utf-8') if data else None

        req = Request(url, data=body, headers=headers, method=method)

        try:
            with urlopen(req, timeout=30) as response:
                return json.loads(response.read().decode('utf-8'))
        except HTTPError as e:
            error_body = e.read().decode('utf-8')
            try:
                error_data = json.loads(error_body)
                return error_data
            except json.JSONDecodeError:
                return {'status': 'error', 'error': {'message': error_body, 'code': str(e.code)}}
        except URLError as e:
            return {'status': 'error', 'error': {'message': str(e.reason), 'code': 'NetworkError'}}

    def get(self, endpoint: str) -> dict:
        return self._request('GET', endpoint)

    def post(self, endpoint: str, data: dict = None) -> dict:
        return self._request('POST', endpoint, data)

    def delete(self, endpoint: str) -> dict:
        return self._request('DELETE', endpoint)

    # System
    def health_check(self) -> dict:
        return self.get('system/health')

    def get_status(self) -> dict:
        return self.get('system/status')

    # Organizations
    def list_organizations(self) -> dict:
        return self.get('organizations')

    def create_organization(self, name: str, permalink: str, owner_email: str, time_zone: str = None) -> dict:
        data = {
            'name': name,
            'permalink': permalink,
            'owner_email': owner_email
        }
        if time_zone:
            data['time_zone'] = time_zone
        return self.post('organizations', data)

    def get_organization(self, org_id: str) -> dict:
        return self.get(f'organizations/{org_id}')

    # Servers
    def list_servers(self, organization_id: str = None) -> dict:
        if organization_id:
            return self.get(f'organizations/{organization_id}/servers')
        return self.get('servers')

    def create_server(self, organization_id: str, name: str, mode: str = 'Live') -> dict:
        data = {
            'name': name,
            'mode': mode
        }
        return self.post(f'organizations/{organization_id}/servers', data)

    def get_server(self, server_id: str) -> dict:
        return self.get(f'servers/{server_id}')

    # Domains
    def list_domains(self, server_id: str) -> dict:
        return self.get(f'servers/{server_id}/domains')

    def create_domain(self, server_id: str, name: str, outgoing: bool = True, incoming: bool = False) -> dict:
        data = {
            'name': name,
            'outgoing': outgoing,
            'incoming': incoming
        }
        return self.post(f'servers/{server_id}/domains', data)

    def verify_domain(self, server_id: str, domain_id: str) -> dict:
        return self.post(f'servers/{server_id}/domains/{domain_id}/verify')

    def check_domain_dns(self, server_id: str, domain_id: str) -> dict:
        return self.post(f'servers/{server_id}/domains/{domain_id}/check_dns')

    def delete_domain(self, server_id: str, domain_id: str) -> dict:
        return self.delete(f'servers/{server_id}/domains/{domain_id}')


class CLI:
    """Interactive CLI for Postal"""

    def __init__(self, api: PostalAPI):
        self.api = api

    @staticmethod
    def print_header(text: str):
        """Print a formatted header"""
        print(f"\n{'=' * 50}")
        print(f"  {text}")
        print('=' * 50)

    @staticmethod
    def print_success(text: str):
        print(f"\n[OK] {text}")

    @staticmethod
    def print_error(text: str):
        print(f"\n[ERROR] {text}")

    @staticmethod
    def print_info(text: str):
        print(f"\n[INFO] {text}")

    @staticmethod
    def prompt(text: str, default: str = None) -> str:
        """Get user input with optional default"""
        if default:
            result = input(f"{text} [{default}]: ").strip()
            return result if result else default
        return input(f"{text}: ").strip()

    @staticmethod
    def prompt_yes_no(text: str, default: bool = True) -> bool:
        """Get yes/no input"""
        suffix = "[Y/n]" if default else "[y/N]"
        result = input(f"{text} {suffix}: ").strip().lower()
        if not result:
            return default
        return result in ('y', 'yes', 'да', 'd')

    @staticmethod
    def select_from_list(items: list, prompt_text: str, name_key: str = 'name', id_key: str = 'uuid') -> dict:
        """Let user select an item from a list"""
        if not items:
            return None

        print(f"\n{prompt_text}:")
        for i, item in enumerate(items, 1):
            name = item.get(name_key, 'Unknown')
            uuid = item.get(id_key, '')[:8]
            extra = ''
            if 'permalink' in item:
                extra = f" ({item['permalink']})"
            elif 'token' in item:
                extra = f" (token: {item['token']})"
            print(f"  {i}. {name}{extra} [{uuid}...]")

        print(f"  0. Cancel")

        while True:
            try:
                choice = int(input("\nSelect number: "))
                if choice == 0:
                    return None
                if 1 <= choice <= len(items):
                    return items[choice - 1]
                print("Invalid choice, try again")
            except ValueError:
                print("Please enter a number")

    def check_connection(self) -> bool:
        """Check API connection"""
        print("Checking connection to Postal API...")
        result = self.api.health_check()

        if result.get('status') == 'success':
            self.print_success("Connected to Postal API")
            return True
        else:
            error = result.get('error', {})
            self.print_error(f"Failed to connect: {error.get('message', 'Unknown error')}")
            return False

    def get_or_create_organization(self) -> dict:
        """Get existing organization or create new one"""
        self.print_header("Select Organization")

        result = self.api.list_organizations()

        if result.get('status') != 'success':
            self.print_error(f"Failed to list organizations: {result.get('error', {}).get('message')}")
            return None

        organizations = result.get('data', [])

        if not organizations:
            self.print_info("No organizations found")
            if self.prompt_yes_no("Create a new organization?"):
                return self.create_organization_interactive()
            return None

        print(f"\nFound {len(organizations)} organization(s)")

        # Add option to create new
        org = self.select_from_list(organizations, "Available organizations")

        if org is None:
            if self.prompt_yes_no("Create a new organization instead?"):
                return self.create_organization_interactive()
            return None

        return org

    def create_organization_interactive(self) -> dict:
        """Create a new organization interactively"""
        self.print_header("Create New Organization")

        name = self.prompt("Organization name")
        if not name:
            self.print_error("Name is required")
            return None

        permalink = self.prompt("Permalink (URL slug)", name.lower().replace(' ', '-'))
        owner_email = self.prompt("Owner email address")

        if not owner_email:
            self.print_error("Owner email is required")
            return None

        time_zone = self.prompt("Time zone", "UTC")

        print(f"\nCreating organization '{name}'...")
        result = self.api.create_organization(name, permalink, owner_email, time_zone)

        if result.get('status') == 'success':
            self.print_success(f"Organization '{name}' created!")
            return result.get('data')
        else:
            error = result.get('error', {})
            self.print_error(f"Failed to create organization: {error.get('message')}")
            if 'details' in error:
                for field, errors in error['details'].items():
                    print(f"  - {field}: {', '.join(errors)}")
            return None

    def get_or_create_server(self, organization: dict) -> dict:
        """Get existing server or create new one"""
        self.print_header("Select Server")

        org_id = organization.get('permalink') or organization.get('uuid')
        result = self.api.list_servers(org_id)

        if result.get('status') != 'success':
            self.print_error(f"Failed to list servers: {result.get('error', {}).get('message')}")
            return None

        servers = result.get('data', [])

        if not servers:
            self.print_info(f"No servers found in organization '{organization.get('name')}'")
            if self.prompt_yes_no("Create a new server?"):
                return self.create_server_interactive(organization)
            return None

        print(f"\nFound {len(servers)} server(s)")

        server = self.select_from_list(servers, "Available servers")

        if server is None:
            if self.prompt_yes_no("Create a new server instead?"):
                return self.create_server_interactive(organization)
            return None

        return server

    def create_server_interactive(self, organization: dict) -> dict:
        """Create a new server interactively"""
        self.print_header("Create New Server")

        name = self.prompt("Server name")
        if not name:
            self.print_error("Name is required")
            return None

        print("\nServer mode:")
        print("  1. Live - for production use")
        print("  2. Development - for testing")
        mode_choice = self.prompt("Select mode", "1")
        mode = "Development" if mode_choice == "2" else "Live"

        org_id = organization.get('permalink') or organization.get('uuid')

        print(f"\nCreating server '{name}' in {mode} mode...")
        result = self.api.create_server(org_id, name, mode)

        if result.get('status') == 'success':
            self.print_success(f"Server '{name}' created!")
            data = result.get('data', {})

            # Show credentials if available
            if 'credentials' in data and data['credentials']:
                print("\n  API Credentials created:")
                for cred in data['credentials']:
                    print(f"    - Name: {cred.get('name')}")
                    print(f"      Key: {cred.get('key')}")

            return data
        else:
            error = result.get('error', {})
            self.print_error(f"Failed to create server: {error.get('message')}")
            if 'details' in error:
                for field, errors in error['details'].items():
                    print(f"  - {field}: {', '.join(errors)}")
            return None

    def add_domain_interactive(self, server: dict) -> dict:
        """Add a domain to server interactively"""
        self.print_header("Add Domain")

        server_id = server.get('uuid')

        # Show existing domains
        result = self.api.list_domains(server_id)
        if result.get('status') == 'success':
            domains = result.get('data', [])
            if domains:
                print(f"\nExisting domains on server '{server.get('name')}':")
                for d in domains:
                    status = "verified" if d.get('verified') else "unverified"
                    print(f"  - {d.get('name')} [{status}]")

        domain_name = self.prompt("\nDomain name to add (e.g., example.com)")
        if not domain_name:
            self.print_error("Domain name is required")
            return None

        # Clean domain name
        domain_name = domain_name.lower().strip()
        if domain_name.startswith('http://') or domain_name.startswith('https://'):
            domain_name = domain_name.split('//')[1].split('/')[0]

        outgoing = self.prompt_yes_no("Enable for outgoing mail?", True)
        incoming = self.prompt_yes_no("Enable for incoming mail?", False)

        print(f"\nAdding domain '{domain_name}'...")
        result = self.api.create_domain(server_id, domain_name, outgoing, incoming)

        if result.get('status') == 'success':
            self.print_success(f"Domain '{domain_name}' added!")
            domain = result.get('data', {})

            # Show DNS records to configure
            self.show_dns_instructions(domain)

            # Ask to verify
            if self.prompt_yes_no("\nTry to verify domain now?", False):
                self.verify_domain_interactive(server_id, domain)

            return domain
        else:
            error = result.get('error', {})
            self.print_error(f"Failed to add domain: {error.get('message')}")
            if 'details' in error:
                for field, errors in error['details'].items():
                    print(f"  - {field}: {', '.join(errors)}")
            return None

    def show_dns_instructions(self, domain: dict):
        """Show DNS configuration instructions"""
        print("\n" + "-" * 50)
        print("DNS CONFIGURATION REQUIRED")
        print("-" * 50)

        print(f"\nFor domain: {domain.get('name')}")

        # Verification TXT record
        if domain.get('dns_verification_string'):
            print("\n1. VERIFICATION (TXT record):")
            print(f"   Host: @")
            print(f"   Type: TXT")
            print(f"   Value: {domain.get('dns_verification_string')}")

        # SPF record
        if domain.get('spf_record'):
            print("\n2. SPF (TXT record):")
            print(f"   Host: @")
            print(f"   Type: TXT")
            print(f"   Value: {domain.get('spf_record')}")

        # DKIM record
        if domain.get('dkim_record_name') and domain.get('dkim_record'):
            print("\n3. DKIM (TXT record):")
            print(f"   Host: {domain.get('dkim_record_name')}")
            print(f"   Type: TXT")
            print(f"   Value: {domain.get('dkim_record')}")

        # Return path
        if domain.get('return_path_domain'):
            print("\n4. RETURN PATH (CNAME record):")
            print(f"   Host: psrp")
            print(f"   Type: CNAME")
            print(f"   Value: {domain.get('return_path_domain')}")

        print("\n" + "-" * 50)

    def verify_domain_interactive(self, server_id: str, domain: dict):
        """Try to verify domain"""
        domain_id = domain.get('uuid')

        print("Attempting to verify domain...")
        result = self.api.verify_domain(server_id, domain_id)

        if result.get('status') == 'success':
            data = result.get('data', {})
            if data.get('verified') or data.get('already_verified'):
                self.print_success("Domain verified successfully!")
            else:
                self.print_info("Verification attempted - check domain status")
        else:
            error = result.get('error', {})
            self.print_error(f"Verification failed: {error.get('message')}")
            print("Make sure DNS records are properly configured and propagated")

    def list_domains_interactive(self, server: dict):
        """List all domains on a server"""
        self.print_header(f"Domains on '{server.get('name')}'")

        server_id = server.get('uuid')
        result = self.api.list_domains(server_id)

        if result.get('status') != 'success':
            self.print_error(f"Failed to list domains: {result.get('error', {}).get('message')}")
            return

        domains = result.get('data', [])

        if not domains:
            self.print_info("No domains configured")
            return

        print(f"\nFound {len(domains)} domain(s):\n")

        for d in domains:
            status = "VERIFIED" if d.get('verified') else "UNVERIFIED"
            modes = []
            if d.get('outgoing'):
                modes.append("outgoing")
            if d.get('incoming'):
                modes.append("incoming")
            mode_str = ", ".join(modes) if modes else "none"

            print(f"  {d.get('name')}")
            print(f"    Status: {status}")
            print(f"    Modes: {mode_str}")
            print(f"    UUID: {d.get('uuid')}")
            print()

    def manage_domain_menu(self, server: dict):
        """Domain management submenu"""
        while True:
            self.print_header(f"Domain Management - {server.get('name')}")

            print("\n  1. List domains")
            print("  2. Add new domain")
            print("  3. Verify domain")
            print("  4. Check DNS status")
            print("  5. Delete domain")
            print("  0. Back to main menu")

            choice = self.prompt("\nSelect option")

            if choice == '0':
                break
            elif choice == '1':
                self.list_domains_interactive(server)
            elif choice == '2':
                self.add_domain_interactive(server)
            elif choice == '3':
                self.verify_domain_menu(server)
            elif choice == '4':
                self.check_dns_menu(server)
            elif choice == '5':
                self.delete_domain_menu(server)

            input("\nPress Enter to continue...")

    def verify_domain_menu(self, server: dict):
        """Select and verify a domain"""
        server_id = server.get('uuid')
        result = self.api.list_domains(server_id)

        if result.get('status') != 'success':
            self.print_error("Failed to list domains")
            return

        domains = result.get('data', [])
        unverified = [d for d in domains if not d.get('verified')]

        if not unverified:
            self.print_info("All domains are already verified")
            return

        domain = self.select_from_list(unverified, "Select domain to verify")
        if domain:
            self.verify_domain_interactive(server_id, domain)

    def check_dns_menu(self, server: dict):
        """Check DNS status for a domain"""
        server_id = server.get('uuid')
        result = self.api.list_domains(server_id)

        if result.get('status') != 'success':
            self.print_error("Failed to list domains")
            return

        domains = result.get('data', [])
        if not domains:
            self.print_info("No domains to check")
            return

        domain = self.select_from_list(domains, "Select domain to check DNS")
        if not domain:
            return

        print(f"\nChecking DNS for {domain.get('name')}...")
        result = self.api.check_domain_dns(server_id, domain.get('uuid'))

        if result.get('status') == 'success':
            data = result.get('data', {})
            dns_status = data.get('dns_status', {})

            print(f"\nDNS Status for {data.get('name')}:")
            print(f"  Overall: {'OK' if data.get('dns_ok') else 'Issues detected'}")
            print()

            for record_type, status in dns_status.items():
                status_str = status.get('status', 'unknown')
                icon = "[OK]" if status_str == 'OK' else "[!!]"
                print(f"  {icon} {record_type.upper()}: {status_str}")
                if status.get('error'):
                    print(f"      Error: {status.get('error')}")
        else:
            self.print_error(f"Failed to check DNS: {result.get('error', {}).get('message')}")

    def delete_domain_menu(self, server: dict):
        """Delete a domain"""
        server_id = server.get('uuid')
        result = self.api.list_domains(server_id)

        if result.get('status') != 'success':
            self.print_error("Failed to list domains")
            return

        domains = result.get('data', [])
        if not domains:
            self.print_info("No domains to delete")
            return

        domain = self.select_from_list(domains, "Select domain to DELETE")
        if not domain:
            return

        if self.prompt_yes_no(f"Are you sure you want to delete '{domain.get('name')}'?", False):
            result = self.api.delete_domain(server_id, domain.get('uuid'))
            if result.get('status') == 'success':
                self.print_success(f"Domain '{domain.get('name')}' deleted")
            else:
                self.print_error(f"Failed to delete: {result.get('error', {}).get('message')}")

    def quick_add_domain(self):
        """Quick workflow to add a domain"""
        self.print_header("Quick Add Domain")

        # Step 1: Select organization
        organization = self.get_or_create_organization()
        if not organization:
            return

        self.print_success(f"Selected organization: {organization.get('name')}")

        # Step 2: Select server
        server = self.get_or_create_server(organization)
        if not server:
            return

        self.print_success(f"Selected server: {server.get('name')}")

        # Step 3: Add domain
        domain = self.add_domain_interactive(server)
        if domain:
            self.print_success("Domain setup complete!")

    def main_menu(self):
        """Main menu loop"""
        while True:
            self.print_header("Postal Management CLI")

            print("\n  1. Quick add domain (guided)")
            print("  2. List organizations")
            print("  3. List all servers")
            print("  4. Manage domains on a server")
            print("  5. Create new organization")
            print("  6. Create new server")
            print("  7. Show system status")
            print("  0. Exit")

            choice = self.prompt("\nSelect option")

            if choice == '0':
                print("\nGoodbye!")
                break
            elif choice == '1':
                self.quick_add_domain()
            elif choice == '2':
                self.list_organizations()
            elif choice == '3':
                self.list_all_servers()
            elif choice == '4':
                self.select_server_for_domains()
            elif choice == '5':
                self.create_organization_interactive()
            elif choice == '6':
                self.create_server_flow()
            elif choice == '7':
                self.show_system_status()
            else:
                print("Invalid option")

            input("\nPress Enter to continue...")

    def list_organizations(self):
        """List all organizations"""
        self.print_header("Organizations")

        result = self.api.list_organizations()

        if result.get('status') != 'success':
            self.print_error(f"Failed: {result.get('error', {}).get('message')}")
            return

        orgs = result.get('data', [])

        if not orgs:
            self.print_info("No organizations found")
            return

        print(f"\nFound {len(orgs)} organization(s):\n")

        for org in orgs:
            status = "SUSPENDED" if org.get('suspended') else "Active"
            print(f"  {org.get('name')} ({org.get('permalink')})")
            print(f"    Status: {status}")
            print(f"    UUID: {org.get('uuid')}")
            print()

    def list_all_servers(self):
        """List all accessible servers"""
        self.print_header("All Servers")

        result = self.api.list_servers()

        if result.get('status') != 'success':
            self.print_error(f"Failed: {result.get('error', {}).get('message')}")
            return

        servers = result.get('data', [])

        if not servers:
            self.print_info("No servers found")
            return

        print(f"\nFound {len(servers)} server(s):\n")

        for s in servers:
            status = "SUSPENDED" if s.get('suspended') else s.get('mode', 'Unknown')
            org = s.get('organization', {})
            print(f"  {s.get('name')} (token: {s.get('token')})")
            print(f"    Organization: {org.get('permalink', 'Unknown')}")
            print(f"    Mode: {status}")
            print(f"    UUID: {s.get('uuid')}")
            print()

    def select_server_for_domains(self):
        """Select a server to manage domains"""
        result = self.api.list_servers()

        if result.get('status') != 'success':
            self.print_error(f"Failed: {result.get('error', {}).get('message')}")
            return

        servers = result.get('data', [])

        if not servers:
            self.print_info("No servers available")
            return

        server = self.select_from_list(servers, "Select server")
        if server:
            self.manage_domain_menu(server)

    def create_server_flow(self):
        """Create server flow - first select org"""
        org = self.get_or_create_organization()
        if org:
            self.create_server_interactive(org)

    def show_system_status(self):
        """Show system status"""
        self.print_header("System Status")

        result = self.api.get_status()

        if result.get('status') != 'success':
            self.print_error(f"Failed: {result.get('error', {}).get('message')}")
            return

        data = result.get('data', {})

        print(f"\n  Version: {data.get('version', 'Unknown')}")
        print(f"  Hostname: {data.get('hostname', 'Unknown')}")

        if 'database' in data:
            db = data['database']
            print(f"\n  Database:")
            print(f"    Connected: {db.get('connected', False)}")

        if 'message_db' in data:
            mdb = data['message_db']
            print(f"\n  Message Database:")
            print(f"    Connected: {mdb.get('connected', False)}")

        if 'queued_worker' in data:
            qw = data['queued_worker']
            print(f"\n  Worker:")
            print(f"    Running: {qw.get('running', False)}")


def main():
    parser = argparse.ArgumentParser(
        description='Postal Management API CLI Tool',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --url https://postal.example.com --api-key abc123

  Or use environment variables:
    export POSTAL_URL=https://postal.example.com
    export POSTAL_API_KEY=abc123
    %(prog)s

  Quick add domain:
    %(prog)s --url https://postal.example.com --api-key abc123 --quick-add
        """
    )

    parser.add_argument(
        '--url', '-u',
        default=os.environ.get('POSTAL_URL'),
        help='Postal server URL (or set POSTAL_URL env var)'
    )

    parser.add_argument(
        '--api-key', '-k',
        default=os.environ.get('POSTAL_API_KEY'),
        help='Management API key (or set POSTAL_API_KEY env var)'
    )

    parser.add_argument(
        '--quick-add', '-q',
        action='store_true',
        help='Jump directly to quick add domain workflow'
    )

    args = parser.parse_args()

    # Validate required args
    if not args.url:
        print("Error: Postal URL is required")
        print("  Use --url or set POSTAL_URL environment variable")
        sys.exit(1)

    if not args.api_key:
        print("Error: API key is required")
        print("  Use --api-key or set POSTAL_API_KEY environment variable")
        sys.exit(1)

    # Create API client
    api = PostalAPI(args.url, args.api_key)
    cli = CLI(api)

    # Check connection
    if not cli.check_connection():
        sys.exit(1)

    try:
        if args.quick_add:
            cli.quick_add_domain()
        else:
            cli.main_menu()
    except KeyboardInterrupt:
        print("\n\nInterrupted. Goodbye!")
        sys.exit(0)


if __name__ == '__main__':
    main()
