<img src="docs/banner-combined.svg" alt="pihole-ha banner" width="100%">

# pihole-ha

Highly-available home DNS with automatic failover.

A single Pi-hole is a single point of failure: if it goes down, most devices on the network lose name resolution outright. This repo documents a small, self-hosted setup that removes that single point of failure with two Pi-hole instances, `dnsdist` for health-checked DNS failover between them, and `keepalived` for a floating virtual IP — plus monitoring, crash forensics, and an optional status dashboard. It's a real, running home-network setup, written up as a feasibility study rather than a polished product: use it as a reference architecture and adapt it to your own environment.

**🔴 [Live demo dashboard](https://zorroficator.github.io/pihole-ha/)** — static demo using bundled sample data, no backend required.

Full documentation, architecture diagram, and deploy steps are in the language-specific READMEs below.

🇩🇪 [Deutsch](README_DE.md) &nbsp;|&nbsp; 🇬🇧 [English](README_EN.md)
