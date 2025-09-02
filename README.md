# CURRENT STATE: partial
Finally boots and logs into hyprland! Currently finishing nixos-rebuild workflow, helpers, and main_configuration defaults. Check [here](https://github.com/PopCat19/nixos-shimboot#progress-and-obstacles) for current progress.

## This is a vibecoded project
As mentioned in the header:\
**This repository and its codebase is *mostly* generated with a Large-Language Model**.

Do not expect this to be a reliable and/or functional codebase. This is *veeery* experimental, and thus, should be treated as a proof of concept.\
|\
Consider creating a fork if you're serious in building a functional NixOS shimboot or similar, if needed.

I made this project because no one (as far as I've seen) has made a NixOS shimboot (yet?). Hence, I created this repo since the existing scripts from [ading2210/shimboot](https://github.com/ading2210/shimboot) is incompatible to build with a non-FHS distro like NixOS.

I've made a bunch of progress initially from [nixos-shimboot-legacy](https://github.com/PopCat19/nixos-shimboot-legacy/tree/qemu-method2), which was also a fork from [shimboot-nixos](https://github.com/PopCat19/shimboot-nixos). 

The reason I made this repo and moved from [nixos-shimboot-legacy](https://github.com/PopCat19/nixos-shimboot-legacy/tree/qemu-method2) is due to the inherited contributers and commits from [ading2210/shimboot](https://github.com/ading2210/shimboot), which considering how I'll only use the bootloader and systemd `mount_nofollow` patch from that repo, I wanted to initialize a clean repo to avoid misconceptions. (with also how I expected this repo to be experimental since I vibecoded most of it)

So far it's been unsurprisingly miserable and messy; this project itself could fit in Michael MJD's "but everything goes wrong" series. That being said, it does make progress considerably rewarding.

Check out [nixos-shimboot-legacy](https://github.com/PopCat19/nixos-shimboot-legacy/tree/qemu-method2) if you want to try out a bootable (dedede) NixOS that only boots into LightDM since the home environment is borked to the brim! (It's not documented well, be warned)

## What's shimboot?
A helpful excerpt from [ading2210/shimboot](https://github.com/ading2210/shimboot)'s [README](https://github.com/PopCat19/shimboot-nixos/raw/refs/heads/main/README.md):
> Shimboot is a collection of scripts for patching a Chrome OS RMA shim to serve as a bootloader for a standard Linux distribution. It allows you to boot a full desktop Debian install on a Chromebook, without needing to unenroll it or modify the firmware.
>
> Chrome OS RMA shims are bootable disk images which are designed to run a variety of diagnostic utilities on Chromebooks, and they'll work even if the device is enterprise enrolled. Unfortunately for Google, there exists a security flaw where the root filesystem of the RMA shim is not verified. This lets us replace the rootfs with anything we want, including a full Linux distribution.
>
> Simply replacing the shim's rootfs doesn't work, as it boots in an environment friendly to the RMA shim, not regular Linux distros. To get around this, a separate bootloader is required to transition from the shim environment to the main rootfs. This bootloader then runs pivot_root to enter the rootfs, where it then starts the init system.
>
> Another problem is encountered at this stage: the Chrome OS kernel will complain about systemd's mounts, and the boot process will hang. A simple workaround is to apply a patch to systemd, and then it can be recompiled and hosted at a repo somewhere.
>
> After copying all the firmware from the recovery image and shim to the rootfs, we're able to boot to a mostly working XFCE desktop.
>
> The main advantages of this approach are that you don't need to touch the device's firmware in order to run Linux. Simply rebooting and unplugging the USB drive will return the device to normal, which can be useful if the device is enterprise enrolled. However, since we are stuck with the kernel from the RMA shim, some features such as audio and suspend may not work.

**TLDR: gnu/linux on (most) chromebooks, except it runs from a persistent USB and can run cool stuff like Arch btw (and most distros) And before you ask, no one tried to shimboot SteamOS/Bazzite as of writing. (even so, your phone could practially run better frames)**

## Why vibecode?
My controversial excuses for vibecoding this project are, but not limited to:
1. Being unapologetically lazy
2. Reading docs are too overwhemingly complicated for my current mental health (probably too dyslexic to understand even fundamental concepts from walls of text)
3. Enjoying some suffering from my lack of understanding in technical concepts and making things miserably difficult than it otherwise would've had been
4. Not being a programmer (I will still hold accountable for this mess)
5. Just wanting NixOS and hyprland to run on an locked-down chromebook while having access to it
6. Accessibility to do something of interest without seeking a psychiatrist from the learning curve
7. Too nervous to work with serious and cool people

**TLDR: "skill issue"**

## Why flake?
Sure, [nixos-shimboot-legacy](https://github.com/PopCat19/nixos-shimboot-legacy) (kinda) worked to build a bootable NixOS with frankenstein scripts running on hopes and dreams, yet it wasn't functional enough to even get past LightDM. 

The user environment is so borked, the system can't even find anything after logging into LightDM. (session PATH was missing core commands: mkdir, systemctl, Hyprland weren't found in the user session, so login fails after LightDM) I really didn't understand why, as if I hadn't realized that we were shoving many, many impure tweaks to get it booting.

Then, the thought of using a minimal liveiso image under qemu environment to create a working ROOTFS that most likely has a working user environment came alight. Yet, after attempting that, it was just failure. (pain)

So, I resorted back to [nixos-generators](https://github.com/nix-community/nixos-generators) to try again, this time using flake with `raw-efi` setting. (I don't know if this makes a difference, but I'd rather find out what happens)

That being said, if it's not possible right now, that's fine and kinda expected. Even if it means using an imperative, impure mess of scripts, if NixOS can work and be actually functional, then it'll be a great foundation to start creating a declarative build, if deemed possible by then.

**TLDR: I want to see if It's really possible to create a pure, reproducible (and actually functional) NixOS shimboot. If not, we'll see if NixOS shimboot is possible first.**

## Progress and obstacles
Flake status and roadmap for the current branch:
- [x] Builds without errors
- [x] Builds current NixOS configuration via [`nixos-generators`](https://github.com/nix-community/nixos-generators)
- [x] Patches RMA shim's `initramfs` with shimboot bootloader and partitions into p2 (currently will require `--impure` for now)
- [x] Partitions in ChromeOS format
- [x] Builds bootable shim bootloader
- [x] Builds bootable NixOS
- [x] Builds bootable NixOS with running `kill-frecon` service (allowing graphics within shim)
- [x] Builds functional NixOS with running greeter (LightDM/SDDM)
- [x] Builds functional NixOS with running user environment (probably with proper home-manager setup)
- [x] PARTIAL: Builds functional NixOS with running hyprland (or xfce4)
- [x] Have functional networking
- [x] UNVERIFIED: Have recovery kernel drivers
- [x] `nix-shell -p firefox` works (firefox profile errors; user environment should be checked; note limited space without `expand_rootfs`)
- [x] Builds functional NixOS with `nixos-rebuild` support (will require `--options disable sandbox` on kernels below 5.6 due to required kernel namespaces)
- [ ] Minimal base_configuration to save space
- [ ] Better main_configuration for hyprland and home-manager rice
- [ ] Builds functional NixOS with LUKS2 support (never done this in my life ;-;)

Current obstacles:
- My irrefutable inexperience/unfamiliarity with the technical aspects of this codebase bottlenecking what needs to be done.

## Binary cache for patched systemd

This project configures the NixOS system image and the on-device helper-generated /etc/nixos to use a Cachix binary cache for the patched systemd. This avoids compiling systemd on Chromebook hardware.

- Substituter: https://shimboot-systemd-nixos.cachix.org
- Trusted public key: `shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA=`

Notes:
- The base image includes these settings via nix.settings.
- The setup_nixos_config helper also writes them into /etc/nixos/configuration.nix so nixos-rebuild on device uses the cache automatically.
- If you maintain your own configuration, add:
```nix
  nix.settings.substituters = [ "https://shimboot-systemd-nixos.cachix.org" ];
  nix.settings.trusted-public-keys = [ "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA=" ];
```

## The Sauce
Bootloader and systemd patches as well as the reference for bootstrapping, partitioning, and workarounds are sourced from: [ading2210/shimboot](https://github.com/ading2210/shimboot) and [ading2210/chromeos-systemd](https://github.com/ading2210/chromeos-systemd)

Miscellaneously, my current dev enviroment consists of:
- [NixOS+Hyprland](https://github.com/PopCat19/popcat19-nixos-hm)
- [VSCodium](https://github.com/VSCodium/vscodium)
  - [Kilo Code](https://github.com/Kilo-Org/kilocode)
    - Common APIs: [ChutesAI](https://chutes.ai/), [Kilo](https://kilocode.ai/docs/providers/kilocode), [OpenRouter](https://openrouter.ai/)
    - Common models: 
      1. [`openai/gpt-5`](https://openrouter.ai/openai/gpt-5)
      2. [`x-ai/grok-code-fast-1`](https://openrouter.ai/x-ai/grok-code-fast-1)
      3. [`openai/gpt-5-mini`](https://openrouter.ai/openai/gpt-5-mini)
    - Common MCPs: 
      [context7](https://github.com/upstash/context7), [exa](https://github.com/exa-labs/exa-mcp-server), [brave-search](https://github.com/brave/brave-search-mcp-server), [sequential-thinking](https://github.com/arben-adm/mcp-sequential-thinking), [filesystem](https://github.com/mark3labs/mcp-filesystem-server)

## Credits:
- [ading2210](https://github.com/ading2210) - for creating the [original shimboot repository](https://github.com/ading2210/shimboot) and giving me an idea to generate NixOS shimboot
- [ading2210/shimboot](https://github.com/ading2210/shimboot) - `bootloader/` source
- [ading2210/chromeos-systemd](https://github.com/ading2210/chromeos-systemd) - systemd `mount_nofollow` patch source to resolve/workaround `Failed to mount API filesystems` error
- [discussion thread](https://github.com/ading2210/shimboot/discussions/335) - useful feedbacks from my idea
- [nixos-generators](https://github.com/nix-community/nixos-generators) - builds nixos image from a configuration for use in ROOTFS