# How to Start SOL Monitoring

## Current Device: 452

IPMI: 172.16.33.27
User: Administrator  
Password: (in .env)

## Start Monitoring

**In a dedicated terminal window, run:**

```bash
cd /Users/hanneszietsman/Code/hydrahost
./tools/monitor-sol.sh
```

**Leave this terminal open** - it will continuously capture and log SOL output.

## View Logs While Monitoring

**In a SECOND terminal, run:**

```bash
cd /Users/hanneszietsman/Code/hydrahost  
tail -f logs/sol-output-*.log
```

Or use:
```bash
./tools/tail-sol.sh
```

## Alternative: HP iLO Web Console

Since this is an HP ProLiant with iLO 4, the **iLO Remote Console** (web-based) you have open will show ALL output including BIOS messages that SOL sometimes misses.

**For complete logging:**
- Use iLO Remote Console for visual monitoring
- Use monitor-sol.sh for automated logging
- Both together give complete coverage

## Current Status

The iLO Remote Console you have open IS showing the boot - you can see BIOS POST and F12 Network Boot option.

The IPMI SOL monitor works but may miss BIOS messages on HP servers (they sometimes only go to iLO console, not serial port).

