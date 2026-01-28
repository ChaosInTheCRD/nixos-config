# Optimized SSH client configuration
{ config, lib, ... }:

{
  programs.ssh = {
    enable = true;

    # Connection multiplexing - reuse existing connections for new sessions
    controlMaster = "auto";
    controlPath = "~/.ssh/control-%C";
    controlPersist = "10m";

    # Compression can help on slower networks
    compression = true;

    # Keep connections alive
    serverAliveInterval = 60;
    serverAliveCountMax = 3;

    extraConfig = ''
      # Use faster ciphers (AES-GCM is hardware accelerated on modern CPUs)
      Ciphers chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,aes256-gcm@openssh.com

      # Disable slow authentication methods
      GSSAPIAuthentication no

      # Speed up connection by disabling host key checking for tailscale
      # (optional - remove if you want strict security)
      Host *.ts.net
        StrictHostKeyChecking accept-new
        UserKnownHostsFile ~/.ssh/known_hosts

      # Reuse connections for git operations
      Host github.com gitlab.com
        ControlMaster auto
        ControlPersist 600
    '';
  };
}
