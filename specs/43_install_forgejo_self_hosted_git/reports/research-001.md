# Research Report: Install Forgejo Self-Hosted Git

- **Task**: 43 - install_forgejo_self_hosted_git
- **Started**: 2026-02-24T12:00:00Z
- **Completed**: 2026-02-24T12:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Sources/Inputs**:
  - NixOS Wiki: Forgejo documentation
  - Forgejo Official Documentation: Config cheat sheet, reverse proxy guide, database preparation
  - MyNixOS: services.forgejo options reference
  - NixOS Wiki: Nginx and ACME configuration
  - Community: GitLab to Forgejo migration tools
- **Artifacts**: specs/43_install_forgejo_self_hosted_git/reports/research-001.md
- **Standards**: report-format.md, status-markers.md

## Project Context

- **Upstream Dependencies**: `configuration.nix` (NixOS system config), existing firewall rules (ports 80/443 already open)
- **Downstream Dependents**: Git repositories (Logos/Theory), CI/CD workflows if Actions enabled
- **Alternative Paths**: Gitea (Forgejo fork parent), GitLab self-hosted, cgit
- **Potential Extensions**: Forgejo Actions for CI/CD, LFS for large files, package registry

## Executive Summary

- Forgejo is well-supported in NixOS via `services.forgejo` module with 37+ configuration options
- SQLite is suitable for small private instances (<100 users); no additional database server required
- Current nixpkgs has Forgejo 14.0.2 available
- Nginx reverse proxy with ACME/Let's Encrypt is straightforward via NixOS declarative config
- Registration can be disabled via `service.DISABLE_REGISTRATION = true`
- GitLab migration can use built-in Forgejo migration tool or external scripts (GEANT/gitlab-to-forgejo)

## Context & Scope

**Objective**: Install and configure Forgejo as a self-hosted private git server on NixOS.

**Requirements**:
1. SQLite database (no external database server)
2. Disabled public registration
3. Nginx reverse proxy with HTTPS
4. Migrate existing private repos from GitLab

**Constraints**:
- Single-user/small team usage
- Must integrate with existing NixOS configuration
- Firewall already allows ports 80/443

## Findings

### 1. NixOS services.forgejo Module

The NixOS module provides comprehensive declarative configuration.

**Key Options**:
- `services.forgejo.enable` - Enable the Forgejo service
- `services.forgejo.database.type` - Database type (default: "sqlite3", also supports "postgres", "mysql")
- `services.forgejo.stateDir` - Data directory (default: /var/lib/forgejo)
- `services.forgejo.repositoryRoot` - Path to git repositories
- `services.forgejo.lfs.enable` - Enable Git LFS support
- `services.forgejo.settings` - Free-form settings written to app.ini
- `services.forgejo.secrets` - Secure credential handling via systemd LoadCredential

**Settings Structure** (maps to app.ini sections):
- `services.forgejo.settings.server.*` - Server configuration (DOMAIN, ROOT_URL, HTTP_PORT)
- `services.forgejo.settings.service.*` - Service settings (DISABLE_REGISTRATION, REQUIRE_SIGNIN_VIEW)
- `services.forgejo.settings.database.*` - Database settings
- `services.forgejo.settings.security.*` - Security settings

### 2. SQLite vs PostgreSQL

**SQLite Advantages** (recommended for this use case):
- No additional database server required
- Zero configuration - works out of the box
- Single file storage, easy backup
- Sufficient for <100 users with moderate activity
- WAL mode available for better concurrent access

**When to Consider PostgreSQL**:
- Multiple hundreds of users
- Heavy concurrent write operations
- Already running PostgreSQL for other services

**SQLite Configuration**:
```nix
services.forgejo = {
  enable = true;
  database.type = "sqlite3";
  # Database stored at ${stateDir}/data/forgejo.db by default
};
```

### 3. Private Instance Configuration

**Disable Registration**:
```nix
services.forgejo.settings.service.DISABLE_REGISTRATION = true;
```

**Require Authentication for All Pages**:
```nix
services.forgejo.settings.service.REQUIRE_SIGNIN_VIEW = true;
```

**Disable External Dependencies** (optional):
```nix
services.forgejo.settings.server.OFFLINE_MODE = true;  # Disable CDN/Gravatar
```

### 4. Nginx Reverse Proxy with HTTPS

**Complete Configuration Pattern**:
```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.services.forgejo;
  srv = cfg.settings.server;
in
{
  # Enable Nginx
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts.${srv.DOMAIN} = {
      enableACME = true;
      forceSSL = true;
      extraConfig = ''
        client_max_body_size 512M;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString srv.HTTP_PORT}";
        proxyWebsockets = true;  # For git push/pull
      };
    };
  };

  # ACME configuration
  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@example.com";
  };

  # Nginx needs acme group for certificates
  users.users.nginx.extraGroups = [ "acme" ];
}
```

**Required Headers** (handled by recommendedProxySettings):
- `X-Real-IP` - Client's actual IP
- `X-Forwarded-For` - Client IP chain
- `X-Forwarded-Proto` - Original protocol (https)
- `Host` - Original host header

### 5. First-Time Setup

**Admin User Creation** (two methods):

1. **Web Interface**: First access to `http://localhost:3000/install` shows setup wizard
2. **Command Line**:
   ```bash
   sudo -u forgejo forgejo admin user create \
     --username admin \
     --password 'secure-password' \
     --email admin@example.com \
     --admin
   ```

**Lock Installation After Setup**:
```nix
services.forgejo.settings.security.INSTALL_LOCK = true;
```

### 6. GitLab Migration

**Built-in Migration Tool**:
- Forgejo has native migration support via web UI
- Settings > Migrations > GitLab
- Requires GitLab personal access token with read_api, read_repository scopes

**External Tools**:
- [GEANT/gitlab-to-forgejo](https://github.com/GEANT/gitlab-to-forgejo) - Python script for bulk migration
- [benmepham/MigrateGitlabToForgejo](https://github.com/benmepham/MigrateGitlabToForgejo) - Automated namespace migration

**Migration Process**:
1. Create GitLab personal access token
2. Use Forgejo web UI: New Repository > Migrate from GitLab
3. Enter GitLab URL, token, and select repositories
4. Issues, pull requests, and wikis can be migrated

### 7. Known Issues and Considerations

**Recent NixOS Issues**:
- **stateDir Bug** (Feb 2025): Using custom `services.forgejo.stateDir` may cause permission issues with secrets in /run/credentials. Workaround: use default stateDir.
- **Secrets Configuration**: Avoid using `SECRET_KEY_URI` in settings; use `services.forgejo.secrets` instead.

**Port Conflicts**:
- Default HTTP_PORT is 3000
- Ensure no other service uses this port (check with `ss -tlnp | grep 3000`)

**SSH Access** (optional):
- Default SSH port is 22
- Can be changed via `services.forgejo.settings.server.SSH_PORT`
- Requires additional firewall rule if enabled

### 8. Complete Minimal Configuration

```nix
{ config, lib, pkgs, ... }:
let
  domain = "git.example.com";
in
{
  services.forgejo = {
    enable = true;
    database.type = "sqlite3";
    lfs.enable = true;
    settings = {
      server = {
        DOMAIN = domain;
        ROOT_URL = "https://${domain}/";
        HTTP_PORT = 3000;
      };
      service = {
        DISABLE_REGISTRATION = true;
        REQUIRE_SIGNIN_VIEW = true;  # Private instance
      };
      security.INSTALL_LOCK = true;  # After initial setup
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts.${domain} = {
      enableACME = true;
      forceSSL = true;
      extraConfig = ''
        client_max_body_size 512M;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:3000";
        proxyWebsockets = true;
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@example.com";
  };

  users.users.nginx.extraGroups = [ "acme" ];

  # Firewall already has 80/443 open in existing configuration.nix
}
```

## Decisions

1. **Use SQLite**: Appropriate for single-user/small team private instance
2. **Use Nginx with ACME**: Leverages existing NixOS declarative patterns
3. **Default stateDir**: Avoid known bug with custom stateDir
4. **Built-in migration**: Use Forgejo's native GitLab migration rather than external scripts

## Recommendations

1. **Implementation Order**:
   - Add Forgejo service to configuration.nix
   - Add Nginx virtualHost configuration
   - Configure ACME for SSL
   - Run `nixos-rebuild switch`
   - Complete web-based initial setup
   - Create admin user
   - Set `INSTALL_LOCK = true`
   - Migrate repositories from GitLab

2. **Domain Setup**:
   - Ensure DNS A record points to server IP
   - ACME requires ports 80/443 accessible from internet

3. **Backup Strategy**:
   - SQLite database at `/var/lib/forgejo/data/forgejo.db`
   - Repositories at `/var/lib/forgejo/repositories`
   - Consider periodic backup to external storage

4. **Security Hardening**:
   - Set `REQUIRE_SIGNIN_VIEW = true` for fully private instance
   - Disable registration after admin account created
   - Use strong admin password
   - Consider SSH key authentication for git operations

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| ACME certificate failure | Low | High | Ensure DNS configured, ports open, test with staging first |
| stateDir bug | Medium | High | Use default stateDir, avoid customization |
| Migration data loss | Low | High | Test migration with non-critical repo first, keep GitLab available |
| Port conflict | Low | Medium | Check port availability before enabling |

## Appendix

### References

- [NixOS Wiki: Forgejo](https://wiki.nixos.org/wiki/Forgejo)
- [MyNixOS: services.forgejo options](https://mynixos.com/options/services.forgejo)
- [Forgejo Config Cheat Sheet](https://forgejo.org/docs/latest/admin/config-cheat-sheet/)
- [Forgejo Reverse Proxy Guide](https://forgejo.org/docs/next/admin/setup/reverse-proxy/)
- [Forgejo Database Preparation](https://forgejo.org/docs/latest/admin/installation/database-preparation/)
- [NixOS Wiki: Nginx](https://wiki.nixos.org/wiki/Nginx)
- [NixOS Wiki: ACME](https://wiki.nixos.org/wiki/ACME)
- [GEANT/gitlab-to-forgejo](https://github.com/GEANT/gitlab-to-forgejo)

### Search Queries Used

1. "NixOS services.forgejo configuration options 2026"
2. "Forgejo NixOS SQLite vs PostgreSQL self-hosted private git"
3. "NixOS Forgejo Nginx reverse proxy HTTPS configuration"
4. "GitLab to Forgejo migration tool migrate repositories 2025"
5. "Forgejo REQUIRE_SIGNIN_VIEW disable public access private instance"
6. "NixOS ACME Let's Encrypt certificate nginx configuration example 2025"
7. "NixOS Forgejo issues problems secrets configuration 2024 2025"
