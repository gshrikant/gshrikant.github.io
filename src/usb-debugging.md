---
title: "Debugging USB with TinyFPGA BX"
date: "2021-07-04"
tags: ["debugging"]
---

I wanted to write a note on a quick debug session to get my TinyFPGA BX board
working with my T450s running Debian Sid (unstable). The board doesn't come
with a separate USB controller (typically a FTDI chip or a microcontroller
running a USB stack). Instead it loads a bootloader design from its QSPI flash
which then presents a CDC class USB device to the host computer which shows up
as a `/dev/ttyACMn` device.

When connected to a USB host - detected by a USB Start of Frame (SoF) packet
the bootloader waits for host commands without exiting. This is indicated by
blinking the onboard LED. When I plugged the device in, however, the LED came
on and blinked for all of 4 seconds before turning off at which point the
device disconnected. I tried using TinyFPGA's `tinyprog` programming tool after
resetting the board only to discover another process holding the device node
file open.

This turned out to be ModemManager (thanks `lsof`) a Network Manager
sub-program designed to talk to USB modems using AT commands. The bootloader
doesn't seem to like this and exits causing the device to "disconnect". After
stopping and disabling the `modemmanager` service via `systemctl` I was hoping
that it would fix my bootloader troubles but unfortunately that didn't seem to
have made a difference. The bootloader LED still turned off after blinking for
about 4-5 seconds followed by the device disconnecting with the following log
messages in `dmesg`:

```
usb 2-1: New USB device found, idVendor=1209, idProduct=2100, bcdDevice=0.00
usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
cdc_acm 2-1:1.0: ttyACM0: USB ACM device
usb 2-1: USB disconnect, device number 9
```

I wasn't sure if the fault lay with the board, the USB cable, the laptop
hardware (USB host controller) or with the host software. I tried plugging in
the device into a Ubuntu 18.04 desktop to see if my board worked and it did!
That eliminated the board as a possible suspect. The next experiment I did was
to disable USB driver autoprobing and see if the bootloader still exited after
a few seconds. Surprisingly, this time around the LED kept happily blinking
away! This eliminated the cable and host USB hardware from the running. The
problem lay with the interaction of the system software and the port.

The next step took a little while but Google led me to `usbmon` which
is a Linux kernel module for sniffing USB packets. Since I now had a working
case (`driver_autoprobe` set to 0) and a non-working case I could compare the
packets transmitted in both cases to try to figure out what went wrong in the
latter. Although `usbmon` exposes a text interface via `debugfs` which captures
raw transmitted USB packets for each bus I found it was much easier to use
Wireshark (which I was surprised to find works for USB packet sniffing too!).

```
$ grep CONFIG_USB_MON /boot/config-$(uname -r) && modprobe usbmon
$ sudo wireshark &
```

At this point we can start sniffing USB packets once we know the bus that our
device is on which we can figure out by looking the `dmesg` output. For
example, in the `dmesg` snippet above the device is on bus 2 which means we
need to look at transactions over `usbmon2` in Wireshark.

Some more digging and a searching revealed that _something_ was suspending
power to the port that the board was connected to. That something then turned
out to be TLP - a power management daemon for Thinkpads that can autosuspend
USB ports (runtime power management) when they are inactive.

Fortunately, there is an option to exclude specific USB devices from TLP's
runtime power management based on their vendor and product ID tuple. I added
the TinyFPGA's VID:PID under `USB_BLACKLIST` in `/etc/default/tlp` and
restarted the TLP service for good measure and the bootloader LED happily
blinked away!
