# Cosmos MVP Plan

**Status:** Ready to build from (2026-11-08). Everything set aside is in
[FUTURE-UPDATES.md](FUTURE-UPDATES.md).

This file says **when** each piece of the minimum viable product (MVP) gets built, and
how Cosmos is meant to be deployed. It is written for a Neurodivergent (ND) reader, in
plain language.

- [MVP-REQUIREMENTS.md](MVP-REQUIREMENTS.md) says what must be true.
- [MVP-SPECIFICATION.md](MVP-SPECIFICATION.md) says how it works.
- This file says when. If they disagree, the requirements and specification are right.

Words are defined in the [glossary](../public/glossary/cosmos-terms.md).

---

## Phases

| Phase | What it delivers | Commitment | State |
|---|---|---|---|
| **1. Trustworthy tests** | Every test runs, nothing hangs, passes from a fresh copy | Committed | Done |
| **2. Commands and AI access** | The running Cosmos, its commands, the console and AI tools, all connected to the real runtime | Committed | Design settled. Not started, apart from the checker fixes |
| **3. The building loop** | Concepts, waves, wires, the history and the three-command test | Committed | Design settled. Not started |
| **4. Close the gaps** | Whatever the compliance matrix still shows | When a project needs it | Waiting |
| **Reference deployment** | Cosmos running as an always-on service | When a project needs a server | Written below. Needs Phase 2. Not built |

### How every step is done

1. Write the tests first, and see them fail.
2. Make the change.
3. Run `nimble verify`.
4. Update the requirement's row in the compliance matrix.
5. Update the guide, reasoning document and glossary if the design changed.

A step is finished when its requirements are **Verified** in the matrix.

### Phase 2 steps

Steps are in build order. Each one depends on those before it.

| Step | What gets built | Requirements |
|---|---|---|
| **2.1 Commands reach their code** | Restore routing for the commands that remain. Fix `--help`, options after the command, and unknown commands. Remove the commands in FUTURE-UPDATES.md from routing | MVP-CLI-1, 6, 8, MVP-SAFE-3 |
| **2.2 One table of actions** | Declare every action once, with one name. Generate commands and help from it | MVP-CLI-5, MVP-AI-1, 3, 6 |
| **2.3 Data firewall for commands** | See the list below | MVP-VAL-2 to 5 |
| **2.4 Home folder** | Connect the home folder code, with a setting to choose it. Add `state/` | MVP-PER-1, MVP-PLAT-2 |
| **2.5 The real running Cosmos** | The three settings, one queue for changes, real frames, running or paused, loading Things, unencrypted default | MVP-CLI-2, 7, 9, MVP-CFG-2, MVP-SAFE-6 |
| **2.6 Clean stop and no hangs** | `cosmos stop`, `Ctrl+C`, stop signals, client time limits, "already running" | MVP-CLI-3, 4, 5, MVP-SAFE-1, 2 |
| **2.7 Logs** | Terminal and file, `cosmos logs`, the previous run | MVP-LIFE-8 |
| **2.8 Console** | Move the console into its own client with no sessions. Folder line, one `cd`, commands that use the current scope, `dir`. Remove `console_main` | MVP-CON-1, 2, 5 to 9 |
| **2.9 AI access** | `describe` replaces `inspect`, the Cosmos's own interface, origin on every change, `cosmos mcp` | MVP-AI-1 to 7 |

`call` on an ordinary Thing arrives in Phase 3, because Things have no code to run until
then. In Phase 2, it works on the Cosmos itself.

**Phase 2 is done when** its requirements are Verified and `tests/KNOWN_FAILURES.txt` is
empty.

**Data firewall, for commands** (step 2.3, spec §4D):

1. **Fix the checker first.** Done 2026-11-08. Every defect below is fixed, each with a
   test that failed before its fix, plus a randomized test.
2. Keep the checker's table for as long as Cosmos runs.
3. Build its rows from the table of actions, and remove the one-entry file.
4. Check every command before it runs. A handler only accepts data that passed.
5. Return a clear error on failure, and write it to the log without the bad data.
6. Add a test that sends a bad request through the real route and proves the handler
   never ran. This is what makes MVP-VAL-3 honestly proven.

**Checker defects found on 2026-11-08. All 14 are fixed.**

Proven by attacking the checker directly:

| # | What happened | Why it matters |
|---|---|---|
| 1 | A nil value crashed the whole program | One bad value stops everything |
| 2 | A forged "passed" result reached the handler | Any code can skip the firewall |
| 3 | A name containing `\|` shared another name's rules. Bad data passed and good data failed | The wrong rules get applied, with no warning |
| 4 | Names differing only by capitals shared rules, with the same result | The same |
| 5 | A very large number passed as text | The code receives the wrong kind of value |
| 6 | Infinity passed as a number | It can break calculations |
| 7 | Text with a NUL character or invalid encoding passed | It can break C code and other programs |
| 8 | A rejected field's name was copied into the failure record | Bad data got out. Here, a fake password appeared |
| 9 | A rejected field's name added a fake line to the log | The log can't be trusted |
| 10 | Valid plain text, numbers and lists were always rejected | Signatures like `(string)->string` can't work |

Number 10 blocks good data rather than letting bad data in.

Found by reading the code:

| # | What is wrong | Why it matters |
|---|---|---|
| 11 | No limit on message size | One huge message can use up all memory |
| 12 | One client that connects and sends nothing blocks everything | Every other command hangs |
| 13 | A wrong argument count scans the whole table | Bad requests cost more than good ones |
| 14 | Two policies either alter data or let unchecked data through | Both break the firewall's rule |

**Tested and sound:** extremely deep nesting gives a normal error instead of a crash. A
repeated field name is resolved once, before the check, so the value checked is the
value delivered.

### Phase 3 steps

Steps are in build order. Each one depends on those before it.

| Step | What gets built | Requirements |
|---|---|---|
| **3.1 Ids, labels and restart** | Cosmos id on first run, Thing ids, the issued-id list, labels and `--as`. Things saved and restored | MVP-ONT-12, MVP-PER-7 |
| **3.2 One manifest** | The one format, signature reading, rhythm in WHEN. `startapp` writes it and the loader reads it | MVP-INT-5, MVP-SCH-4, MVP-DX-1 |
| **3.3 Everything is a Thing** | Concepts at `cosmos.concepts`, WHY from the Concept, inheritance removed | MVP-ONT-1, 2, 7, 11 |
| **3.4 Waves and senses** | Real waves, senses with shapes, delivery in the next frame | MVP-ONT-4, 8, 10 |
| **3.5 The history** | One row per frame, saved. `cosmos history` | MVP-ONT-9, MVP-AI-8 |
| **3.6 Running code** | Separate programs over input, output and error, with a marked turn and a time limit. A crash suspends only that Thing | MVP-INT-6, MVP-SCH-1 to 3 |
| **3.7 Data firewall for Things** | See the list below | MVP-VAL-2 to 5 |
| **3.8 Calls** | One-time wires, tickets, "waiting" replies, answers on `step` | MVP-AI-5 |
| **3.9 Composition** | Parts, wires, `self`, joined routes, the wire check | MVP-INT-7, MVP-ONT-8 |
| **3.10 The headline test** | Three commands from nothing to a described Thing, and one composite example | Requirements, Goal |

**Phase 3 is done when** its requirements are Verified and the three-command test passes
from a fresh copy.

**Data firewall, for Things and waves** (step 3.7, spec §4D):

1. Define the signature format and read it when a Concept loads.
2. Add each Concept's rules to the table.
3. Check every call, and every wave a Thing sends, before it goes anywhere.
4. Record each failure in the history as a `rejected` change.

---

## Reference Deployment

This is the recommended way to run Cosmos as an always-on service on one machine.

**None of this is built or tested yet.** It depends on Phase 2. The service files below
are drafts. They are not part of the MVP tests.

### Which systems

| System | Role |
|---|---|
| **Linux** | The main reference. Most likely place to run Cosmos. |
| **FreeBSD** | The reference BSD. Other BSDs would adapt it. |
| **Windows** | Possible. |
| **macOS** | Possible. |

Development stays on Windows 11 for now (MVP-PLAT-1). Where Cosmos is built and where
it is deployed are separate questions.

### The five rules

1. **One Cosmos per machine.**
2. **The operating system's service manager runs it.** Cosmos stays in the foreground,
   which is what service managers expect. No background mode is needed.
3. **One folder holds everything Cosmos writes.**
4. **It has its own account.** It never runs as root or Administrator.
5. **It is reachable only from the same machine.**

### Where it lives

| What | Linux and FreeBSD | Windows | macOS |
|---|---|---|---|
| The program | `/usr/local/bin/cosmos` | `%ProgramFiles%\Wilder\Cosmos\cosmos.exe` | `/usr/local/bin/cosmos` |
| The home folder | `/var/lib/wilder/cosmos` | `%ProgramData%\Wilder\Cosmos` | `/var/lib/wilder/cosmos` |

The home folder paths are the "system" install paths already in `home.nim`.

**Inside the home folder:**

| Folder | Holds |
|---|---|
| `config/` | The settings file, `cosmos.json` |
| `logs/` | The log files |
| `state/` | Saved data (new, see [what must be built first](#what-must-be-built-first)) |
| `projects/` | Your Concepts |
| `registry/` | Cosmos's own records |
| `messages/`, `cache/`, `temp/` | Working files |

`bin/` stays empty. It is only for personal installs.

**A deliberate departure from convention:** Linux usually splits these across `/etc`,
`/var/log` and `/var/lib`. FreeBSD uses `/var/db`, and macOS uses
`/Library/Application Support`. This plan keeps one folder, the same on Linux and BSD.
There is one place to remember, one thing to back up and one thing to delete.

### Logs

- The log file is `logs/cosmos.log`, inside the home folder.
- The previous run's log is `logs/cosmos.previous.log`.
- `cosmos logs` reads the file, even if Cosmos has crashed.
- On Linux, `journalctl -u cosmos` shows the same notes.
- Logs never contain your data or secrets.
- A service can run for months as one run. Logs only hold startup and shutdown notes
  today, so the file stays small. If Cosmos starts logging more, it will need a size
  limit.

### Permissions

| Item | Setting |
|---|---|
| Account | A dedicated `cosmos` account that can't log in |
| The program | Owned by root. The `cosmos` account can't change it |
| The home folder | Owned by `cosmos`. Only `cosmos` can write. Mode `750` |
| New files | Hidden from other users. `umask 027` |
| People who read logs | Add them to the `cosmos` group |
| Network port | 7700. It is above 1024, so it needs no special privilege |
| Windows | Only the service account and Administrators can open the home folder |

**Create the account:**

```sh
# Linux
useradd --system --home-dir /var/lib/wilder/cosmos --shell /usr/sbin/nologin cosmos

# FreeBSD
pw useradd cosmos -d /var/lib/wilder/cosmos -s /usr/sbin/nologin
```

### Starting and stopping

| System | Service manager | How |
|---|---|---|
| Linux | systemd | The unit file below |
| FreeBSD | rc.d and `daemon` | The script below |
| Windows | Task Scheduler | A task that runs at startup, under the service account, and restarts on failure |
| macOS | launchd | A property list in `/Library/LaunchDaemons`, named `org.wildercode.cosmos`, with `KeepAlive` and `UserName` set |

**Linux draft,** `/etc/systemd/system/cosmos.service`:

```ini
[Unit]
Description=Wilder Cosmos

[Service]
Type=simple
User=cosmos
Group=cosmos
ExecStart=/usr/local/bin/cosmos start --config /var/lib/wilder/cosmos/config/cosmos.json
Restart=on-failure
RestartSec=5
UMask=0027
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
ReadWritePaths=/var/lib/wilder/cosmos

[Install]
WantedBy=multi-user.target
```

**FreeBSD draft,** `/usr/local/etc/rc.d/cosmos`. Turn it on with
`sysrc cosmos_enable=YES`.

```sh
#!/bin/sh
# PROVIDE: cosmos
# REQUIRE: LOGIN FILESYSTEMS
# KEYWORD: shutdown

. /etc/rc.subr

name="cosmos"
rcvar="cosmos_enable"
load_rc_config $name
: ${cosmos_enable:="NO"}

pidfile="/var/run/${name}.pid"
command="/usr/sbin/daemon"
command_args="-r -f -P ${pidfile} -u cosmos /usr/local/bin/cosmos start --config /var/lib/wilder/cosmos/config/cosmos.json"

run_rc_command "$1"
```

### Best practices

- **Back up the whole home folder.** Run `cosmos snapshot` first.
- **Test a restore.** A backup that has never been restored is unproven.
- **Encrypt the disk.** Cosmos stores data unencrypted (MVP-SAFE-6). Use LUKS on Linux,
  GELI or ZFS encryption on FreeBSD, BitLocker on Windows and FileVault on macOS.
- **Don't open port 7700.** Use SSH to reach the machine from elsewhere.
- **Check health with `cosmos describe cosmos`.** Its exit code works in monitoring
  tools.
- **To upgrade:** back up, stop the service, replace the program, start the service.
  Cosmos updates saved data at startup. Keep the previous program until the new one has
  run cleanly.
- **If something fails:** the service manager's status command, `cosmos logs` and the
  plain-text log file all work without a running Cosmos.
- **To remove it:** stop and remove the service, then delete the program, the home
  folder and the account. Nothing else is left behind.

### What must be built first

| # | What is missing | Why it matters |
|---|---|---|
| 1 | Nothing in the running program uses the home folder code yet | Cosmos doesn't know where its home folder is |
| 2 | There is no setting to choose a home folder | A service can't ask for the system location |
| 3 | The home folder has no `state/` folder | Saved data has no agreed place in it |
| 4 | Cosmos handles no stop signals yet | Service managers ask programs to stop with a signal. It must do the same clean stop as `Ctrl+C` and `cosmos stop` |
| 5 | The home folder code treats every BSD as Linux | It gives the right path by accident. It should be explicit |
| 6 | The MVP tests have only run on Windows, through Windows PowerShell | Linux and BSD can't be claimed until the tests pass there |
| 7 | **The command channel has no access control** | Any program on the machine can connect to port 7700 and control Cosmos |

**Until number 7 is solved, only deploy on a machine where you trust every account.**
On Linux, BSD and macOS, a local socket protected by file permissions is the likely
answer.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
