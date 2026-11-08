# Cosmos in Plain Language

**Checked against the technical documents on 2026-11-08.**

This guide says what Cosmos must do and how it will work, without jargon. It covers
the first complete version of Cosmos, called the minimum viable product (MVP).

It is written for a Neurodivergent (ND) reader. Each section stands alone, so you can
jump to any part.

**Good to know:**

- This describes what Cosmos must **become**. Much of it isn't built yet. The
  [compliance matrix](MVP-COMPLIANCE-MATRIX.md) shows what is built and tested.
- The exact wording lives in [MVP-REQUIREMENTS.md](MVP-REQUIREMENTS.md) (what must be
  true) and [MVP-SPECIFICATION.md](MVP-SPECIFICATION.md) (how it works). If this guide
  and those files disagree, those files are right.
- Each section ends with a **Source** line. It names the matching technical entries.
- [Still undecided](#still-undecided) lists the questions the documents don't answer
  yet.
- [MVP-REASONING.md](MVP-REASONING.md) explains why each choice was made.

## Contents

1. [The whole idea](#the-whole-idea)
2. [The words we use](#the-words-we-use)
3. [When the first version is done](#when-the-first-version-is-done)
4. [What exists in a Cosmos](#what-exists-in-a-cosmos)
5. [Waves and wires](#waves-and-wires)
6. [Time and history](#time-and-history)
7. [What a Thing can reach](#what-a-thing-can-reach)
8. [Building with Concepts](#building-with-concepts)
9. [When Things act](#when-things-act)
10. [Starting and stopping](#starting-and-stopping)
11. [Giving Cosmos commands](#giving-cosmos-commands)
12. [The console](#the-console)
13. [How an AI uses Cosmos](#how-an-ai-uses-cosmos)
14. [Settings](#settings)
15. [Saving data](#saving-data)
16. [Checking incoming data](#checking-incoming-data)
17. [Safety](#safety)
18. [Tests and project habits](#tests-and-project-habits)
19. [What is left out](#what-is-left-out)
20. [The order of work](#the-order-of-work)
21. [Still undecided](#still-undecided)

---

## The whole idea

Cosmos is a way to build things logically, in a way that suits an ADHD mind.

- There is one kind of building block: the **Thing**.
- You describe what you want in a **Concept**, which works like a template.
- Things talk by sending **waves**.
- You can connect Things directly with visible **wires**.
- Nothing is hidden, and Cosmos records what happened.
- People and AI use exactly the same controls.

Music tools are the first use, but Cosmos is for building anything. The music tools
are separate projects. Nothing about audio goes in Cosmos itself.

---

## The words we use

Every Cosmos word is defined in one place: the
[glossary](../public/glossary/cosmos-terms.md). Keep it open beside this guide if that
helps.

Two phrases in this guide are plain stand-ins for technical names:

- **The running Cosmos** means the daemon.
- **The command channel** means inter-process communication (IPC).

---

## When the first version is done

The first version is done when all four of these are true:

1. You can create, start and inspect a new Thing in three commands or fewer.
2. A test proves every requirement in this guide.
3. All the tests pass on a fresh copy of the project on Windows.
4. An AI can find, inspect and operate every Thing using the same controls as a person.

The three commands are:

```
cosmos startapp hello
cosmos start --with hello
cosmos describe hello
```

The second command stays open in its own terminal window.

**Source:** Requirements, Goal. Spec §7.

---

## What exists in a Cosmos

**What must be true:**

- Everything that exists is a Thing.
- The Cosmos is the top Thing. Cosmos creates it when it starts. It has no parent.
- Every other Thing sits somewhere inside the Cosmos.
- A Concept is a Thing that acts as a template.
- Every other Thing is made from a Concept.
- Modules, bundles and bridges are not separate kinds of object. They are Things too.
- Waves, wires, the history and frames are **not** Things. They are properties of the
  Cosmos.

**A Concept needs only two things to exist:**

- a WHO (its name)
- a WHY (its purpose)

**A Thing and its Concept:**

- A Thing has its own WHO.
- A Thing uses its Concept's WHY, unless the Thing states its own.
- If there is no WHO, that is an error.
- If neither the Thing nor its Concept has a WHY, that is an error.
- All the other labels are optional. If WANTS or PROVIDES are present, they are checked.

**How it is arranged:**

```
cosmos                  the top Thing
cosmos.concepts         holds every loaded Concept
cosmos.concepts.hello   the Concept called hello
cosmos.hello            a Thing made from hello
```

- Loading a Concept puts it in `cosmos.concepts`.
- A Concept is only a template. It doesn't run or receive waves.
- The name `concepts` is reserved. A Concept that tries to use it is skipped with a
  warning.

**Scope paths:**

- Every Thing has an address made of dots, following what is inside what.
- A Thing's address doesn't depend on which folder its files are in.
- In the console, `cd` changes where you are looking. It never changes anything else.

**Source:** MVP-ONT-1, 2, 3, 5, 6, 7. Spec §4C.1, §4C.2.

---

## Waves and wires

**Waves are the only way Things communicate.**

**A wave without a wire goes everywhere:**

- A wave spreads across the whole Cosmos.
- Every Thing with a matching sense receives it.
- The sense must match the wave's name exactly. There are no patterns or wildcards.
- A wave that nobody senses is still recorded.

**A wire narrows a wave's path:**

- A wire connects one Thing's output to one or more Things' inputs.
- Waves on a wire go only to those destinations. They don't also spread everywhere.
- A wire is like a cable from an output jack. Each thing a Thing PROVIDES is a separate
  jack.
- `keys` means everything `keys` sends.
- `keys.notes` means only the `notes` waves from `keys`.

A wire is written like this. It sends `notes` from `keys` to both `osc` and `display`:

```json
{"from": "keys.notes", "to": ["osc", "display"]}
```

**Wires are checked first:**

- When a Concept loads, Cosmos checks each wire.
- Each destination must be able to accept what the wire carries.
- If one can't, Cosmos reports exactly which wire and destination failed.
- That Concept is skipped with a warning. Everything else carries on.
- Each wave's contents are checked again when it is sent.

**A wave has no address on it.** Only wires and senses decide where it goes. A Thing
can't aim a wave at something outside its reach.

**A call uses a one-time wire.** When a person or AI asks a Thing to do something, the
Cosmos makes a wire to that Thing for one wave. The wire then ends. Only operators can
do this.

**Source:** MVP-ONT-4, 8. Spec §4B.3, §4C.3, §4C.4.

---

## Time and history

**Time:**

- Time in Cosmos is counted in frames, never in clock time.
- A frame is finished when every Thing has had its turn.
- A wave sent in one frame arrives at the start of the **next** frame.
- This means the order Things take their turns can't change what they hear.
- Waves arrive sorted by sender, then by the order they were sent.
- Frames are not the audio clock. Audio projects keep their own clock.

**History:**

- The history is a table with one row per frame.
- The left side of each row is the frame number: **when** it happened.
- The right side is that frame's changes: **what** happened.
- One whole row is called an occurrence.
- A past occurrence can never be altered.
- A frame where nothing happened writes nothing.

**Each change is one of these:**

| Change | Meaning |
|---|---|
| wave | A Thing sent a wave. |
| status | A Thing's state changed. |
| added | A Thing was added. |
| removed | A Thing was removed. |
| failure | A Thing failed during its turn. |
| suspended | A Thing was stopped from taking turns. |
| rejected | Incoming data failed its check. |
| request | An operator's command was carried out. |
| result | A Thing answered a call. |

Every change records who caused it. Deliveries aren't recorded separately, because the
waves, wires and senses already show where each wave went.

**Reading the history:**

| Command | What it shows |
|---|---|
| `cosmos history` | The last 20 frames that had changes. |
| `cosmos history --last 50` | The last 50 instead. |
| `cosmos history --frame 12` | Only frame 12. |
| `cosmos history --thing osc` | Only what involved `osc`. |

**Source:** MVP-ONT-4, 9. Spec §4C.4, §4C.5.

---

## What a Thing can reach

**Scope:**

- A Thing can act on itself and on what is inside it.
- It can't act on its siblings or its parents.
- Anything else can reach a Thing only through its senses or a wire.
- Hearing a wave tells a Thing about the sender. It doesn't let the Thing act on the
  sender.
- Operators work through the Cosmos itself, so they can reach any Thing.
- Operators' commands pass the same checks as everything else.

Scope is guaranteed by how Things are built. A Thing's code only ever gets its own
input and output. It holds no connection to any other Thing.

**Nothing is inherited:**

- A Thing knows only what its Concept declares, what it senses and what is wired to it.
- Nothing passes from a parent to the Things inside it.
- Getting declarations from its own Concept is not inheritance. That is how a Thing is
  made.

**Source:** MVP-ONT-10, 11. Spec §4C.6, §4C.7.

---

## Building with Concepts

Designing Concepts is the main work of building with Cosmos.

**Every Concept is declared the same way:**

- Each one is a `manifest.json` file in its own folder.
- The manifest holds:
  - WHO, a VERSION and the other labels
  - SENSES: the wave names it listens for
  - either an IMPLEMENTATION (its code), or PARTS and WIRES (it is built from others)
- Code can generate the manifest, but the manifest is always the declaration.

**PROVIDES and WANTS:**

- What a Thing offers is declared once, by the Thing that offers it.
- Anything using it refers to it by name and never repeats the details.
- When Cosmos starts, it works out who provides what, before any code runs. The result
  is the same every time.
- If something is missing, ambiguous or doesn't fit, Cosmos reports it clearly.
- If the problem is serious enough, startup stops.
- `cosmos capabilities` lists all of this, one item per line.

**How code talks to Cosmos:**

- Code has only three channels: input, output and error.
- Each message is one line of JavaScript Object Notation (JSON), a plain text data
  format.
- No other channels are allowed: no network connections, shared files or shared memory.

| Channel | What travels on it |
|---|---|
| Input | Waves arriving for this Thing, and calls. A call carries a ticket number. |
| Output | Waves it sends, answers to calls with their ticket number, and its own current state. |
| Error | Problems. Each is recorded in the history. |

- If the code crashes or writes something unreadable, that Thing is suspended. The
  Cosmos keeps running.
- In the first version, code is written in Nim, or C where needed. Other languages come
  later using the same three channels.
- Audio signals never travel this way. An audio Thing's code handles control only.

**Building a Concept from other Concepts:**

- A Concept can be made of other Concepts: its parts and the wires between them.
- Making a Thing from it creates one inner Thing per part, connected by those wires.
- For example, `cosmos.synth` might contain `cosmos.synth.filter`.
- It declares its own WANTS and PROVIDES. Other Things connect to those.
- Anyone can still look inside it.
- Only a Concept with no parts needs code.

**Source:** MVP-INT-1 to 7. Spec §4B.

---

## When Things act

**Each Thing has one rhythm:**

| Rhythm | The Thing acts... |
|---|---|
| Event | when something happens that it perceives. |
| Periodic | at a fixed interval. |
| Continuous | every frame. |
| Manual | when explicitly commanded. |
| Sequence | in a declared order of steps. |

The rhythm is checked when the Thing loads.

**Rules for every frame:**

- The results are deterministic. The same starting state and waves always give the same
  result, so any run can be replayed.
- No Thing can take unlimited time. Things hand back control themselves.
- If one Thing fails, the others carry on.
- A Thing that keeps failing is suspended, with a clear error.

**Source:** MVP-SCH-1 to 4. Spec §3.3.

---

## Starting and stopping

**Starting happens in this fixed order:**

1. Read the settings.
2. Load the information describing the saved data.
3. Confirm the saved copies of the data agree.
4. Update any saved data that uses an older format.
5. Turn on the checker for incoming data.
6. Load the modules that extend Cosmos.
7. Create the top Thing.
8. Start the system that runs frames.
9. Work out who provides what.
10. Load your Things.
11. Start running frames.

**Rules for starting:**

- Starting with no Things at all is fine.
- Missing files never block startup.
- A broken Thing is skipped with a warning. The rest still load.
- No module runs until step 3 has passed.
- Nothing is accepted from outside until step 5 is done.
- If a step fails, startup stops and reports where, why and how to recover.
- That report never includes file paths, secrets or the contents of your data.

**Stopping happens in this fixed order:**

1. Finish saving anything in progress.
2. Save a final copy of the state.
3. Stop running frames.
4. Unload modules.
5. Close the saved data.

**The running Cosmos stays in its terminal window.** There is no hidden background
program. `Ctrl+C` in that window and `cosmos stop` from anywhere do the same clean
shutdown. The network port is released even if shutdown fails.

**Only one part of Cosmos changes anything.** Commands wait in a queue and are carried
out between frames. This prevents two actions colliding, and keeps runs replayable.

**Logs:**

- Each stage is logged under a fixed event name.
- Each note prints in Cosmos's terminal window and is saved to a log file.
- `cosmos logs` reads the file. It works even after a crash.
- The file is in the `logs` folder of Cosmos's home folder.
- Cosmos keeps the current run and the one before it.
- If the file can't be written, Cosmos warns once and keeps running.
- Logs never contain your data or secrets.

**Source:** MVP-LIFE-1 to 8. Spec §3.

---

## Giving Cosmos commands

**Commands:**

| Command | What it does |
|---|---|
| `cosmos`, `cosmos --help`, `cosmos -h` | Shows help. Starts nothing. |
| `cosmos start` | Starts Cosmos. |
| `cosmos stop` | Shuts it down cleanly. |
| `cosmos list`, `step`, `mode`, `add`, `remove`, `pause`, `resume`, `snapshot` | Talk to the running Cosmos. |
| `cosmos methods` | Lists every available action. |
| `cosmos describe <name>` | Describes one Thing. `cosmos describe cosmos` shows the running Cosmos. |
| `cosmos history` | Shows what happened. |
| `cosmos logs` | Shows the log file. |
| `cosmos call <thing> <what>` | Asks a Thing to do something it PROVIDES. |
| `cosmos console` | Opens the console. |
| `cosmos mcp` | Opens the connection for AI tools. |
| `cosmos startapp`, `capabilities`, `concept`, `capability`, `scan`, `ipc`, `notify` | Existing commands. They must be reachable again. |

**Every action has a command.** The commands are generated from the one table of
actions, so none can be left out.

**Some commands work without a running Cosmos:** `startapp`, `capabilities`, `concept`,
`capability`, `scan`, `notify` and `logs`.

**Options for `cosmos start`:**

| Option | Meaning |
|---|---|
| `--mode step` | Start paused. Run one frame per `step` command. |
| `--mode continuous` | Run frames one after another. |
| `--mode periodic` | Run frames at the set frame rate. |
| `--config <path>` | Use this settings file. |
| `--with <path>` | Load this Thing. Can be repeated. |
| `--loglevel <level>` | How much to log: trace, debug, info, warn or error. |
| `--port <number>` | Which network port to use. |

**How commands behave:**

- A bad option stops immediately and shows how to use the command.
- If Cosmos is already running, `cosmos start` says so and starts nothing.
- If Cosmos isn't running, commands that need it say so and exit. They never hang.
- Unknown commands, unknown options and missing values show how to use the command.
- `cosmos restart` doesn't exist in the first version.

**How commands finish:**

| Exit code | Meaning |
|---|---|
| 0 | It worked. |
| 1 | No running Cosmos, no response, or a connection problem. |
| 2 | The command was wrong, or Cosmos reported an error. |

**The command channel:**

- It works only on your own computer, never across a network.
- Each request gets its own connection.
- Each message is one line of JSON, marked with a format version and a unique number.
- The port comes from the settings. The default is 7700. No command has a fixed port.
- Commands give up after 2 seconds and say the running Cosmos isn't responding.

**Source:** MVP-CLI-1 to 9. Spec §3.2, §4, §6.

---

## The console

The console is an interactive screen for looking around a running Cosmos.
`cosmos console` is the only way to open it. It can take `--attach <identity>` and
`--watch <path>`.

**The screen has three layers, always in this order:** status bar, scope line, prompt
line.

| Command | What it does |
|---|---|
| `ls` | Lists what is here, as one flat list. |
| `cd` | Moves where you are looking. |
| `pwd` | Shows where you are looking. |
| `info` | Shows details about a Thing. |
| `peek` | Takes a quick look at data. |
| `state` | Shows a Thing's state. |
| `world` | Shows how Things are linked. |
| `watch` | Follows changes live. `Ctrl+C` returns to the normal screen. |
| `attach` | Connects to an instance. |
| `detach` | Disconnects, cancels watches and resets the screen. |
| `help`, `clear`, `exit` | Help, clear the screen, leave. |

`attach`, `help`, `clear` and `exit` always work. The others give a clear error if you
aren't attached.

**Source:** MVP-CON-1 to 7. Spec §5.

---

## How an AI uses Cosmos

**The rule: there is one set of controls.** The command line, the console and the AI
connection are all clients of the same command channel. Nothing is only for people or
only for AI.

- Every action is one entry in a single table of methods.
- That one table drives the actions, the help and the AI tool list.
- New abilities are added to the table first, so people and AI stay equal.

**An AI needs to learn one pattern: describe, then call.**

- `describe` shows what a Thing is and what it can do: its name, address, manifest,
  wants, provides, rhythm, status and contents.
- `call` asks it to do one of those things.
- The Cosmos itself works the same way. Its abilities include `step`, `pause`,
  `addThing` and `stop`.

**How a call works:**

- Each call gets a ticket number. The answer comes back with the same number.
- If the answer comes within 1 second, you get it straight away.
- If not, you get an immediate "waiting, ticket 7" message instead.
- While Cosmos is paused for stepping, a call waits for the next `step`.
- That `step` shows the answer, so you keep your place.
- Every answer is recorded in the history.
- A Thing that never answers doesn't hold anything up.

**An AI can do everything a person can.** That includes creating a new Thing before
Cosmos is running.

**The same checks apply to everyone:**

- AI requests pass the same validation as all others.
- Every change records who made it, such as `cli` or `mcp:<client name>`.

**Two ways in for an AI:**

- **Command line.** Every action prints a structured result and never needs someone at
  the keyboard.
- **Model Context Protocol (MCP),** a standard way to connect AI tools. `cosmos mcp`
  turns every action into a tool automatically.

If the MCP program isn't running, Cosmos behaves exactly as it would without it. If
Cosmos isn't running, MCP stays open and clearly says so.

**Source:** MVP-AI-1 to 8. Spec §4A.

---

## Settings

- A settings file is optional. With none, Cosmos uses documented defaults.
- Settings are in a JSON file.
- If a setting is given more than once, this order decides. Later beats earlier:
  1. the file
  2. environment variables (`COSMOS_MODE`, `COSMOS_LOG_LEVEL`, `COSMOS_PORT`)
  3. command-line options
- Every value passes the same check, wherever it came from.
- A bad setting is rejected at load time with a clear error.
- Parts of Cosmos are given the settings. They never read the file themselves.

**A known oddity:** "mode" means two things. The settings' mode is development, debug
or production. `start --mode` is how frames run. Both stay for now.

**Source:** MVP-CFG-1 to 4. Spec §3.2, §6.

---

## Saving data

**Cosmos saves in three layers:**

1. the current state
2. a running log that only ever gets added to
3. signed saved copies, called snapshots

**Rules:**

- Every saved entry carries a format version, its frame, a checksum (a value that
  reveals damage), who made it, a unique number and a time.
- Checksums are verified on every read.
- The state can be rebuilt from any two layers, or from one layer plus the log.
- The rebuilt result is deterministic: always the same.
- Files are written to a temporary file and then swapped in. A crash can't leave half a
  file.
- If the layers can't be reconciled, startup stops with a clear report.
- Names used to save data may contain only letters, digits, `_` and `-`, up to 128
  characters.
- Data is **not encrypted** in the first version. Cosmos makes no privacy claim.
  Protecting your disk is the operating system's job, for example BitLocker.

**Source:** MVP-PER-1 to 6, MVP-SAFE-6.

---

## Checking incoming data

The checker is called the prefilter. It sits between the outside world and your Things.

**Not connected yet.** The checker exists and passes its tests, but the running program
doesn't use it so far.

**The rule: no bad data reaches a Concept's code.** This is a data firewall.

**One table holds the rules.** Nobody writes the rules by hand. They come from what is
already declared:

| Rules for | Come from | Ready |
|---|---|---|
| Commands | The table of actions | Before Cosmos accepts anything |
| Things | The PROVIDES signatures in each manifest | When the Concept loads, before its Things run |

**Everything coming in is checked first:**

| Coming in | If it fails |
|---|---|
| A command | You get a clear error, and it doesn't run. |
| A call to a Thing | You get a clear error, and nothing is delivered. |
| A wave a Thing sends | It is recorded as rejected and goes nowhere. |

- A Thing's output counts as outside data.
- A wave whose name its sender didn't declare in PROVIDES is rejected.
- A failed check never shows the bad data.
- Delivery only accepts data that passed. A new route that forgets the check won't
  compile.

**What a signature looks like:** `({pitch:int,label?:string})->bool`. This one takes an
object with a whole-number `pitch` and an optional text `label`. Any other field is
rejected.

**What isn't checked by this table:**

- Settings, saved data and manifests have their own checks.
- Calls between parts of Cosmos's own code aren't checked here. The Nim compiler
  already guarantees those.
- Every public function also keeps its own basic checks.

**The checker must be bullet-proof.** That means:

- It never crashes or hangs, whatever it receives.
- Any error inside it counts as a rejection.
- A value passes only if it exactly matches its rule.
- Only the checker can say something passed.
- Message size and nesting have limits, checked first.
- No incoming data appears in errors or logs, not even a field's name.
- Every known attack has a test, and a randomized test runs too.

Testing can't prove there are no bugs left. It does mean every known kind of attack is
covered. An audit on 2026-11-08 found 14 defects, now fixed. They are listed in
[the plan](MVP-PLAN.md#phase-2-steps).

**Source:** MVP-VAL-1 to 6. Spec §4D.

---

## Safety

- **Reduce, never freeze.** A missing file, missing Cosmos or busy port gives reduced
  function and a clear message. It never hangs or crashes.
- **Recovery needs only the command line.** Fixing a failure never depends on the part
  that failed.
- Commands refuse to work on a whole drive, such as `C:\`.
- `startapp` names may use only letters, digits, `_`, `-`, spaces and dots, up to 64
  characters. This is checked before any file is created.
- Code may not catch every possible error without saying which ones it expects.

**Source:** MVP-SAFE-1 to 5.

---

## Tests and project habits

- `nimble test` runs every test file. None are left out.
- Tests pass on a fresh copy of the project and never rely on files that aren't saved in
  it.
- No test can hang. Each file has a 90-second limit.
- Tests that start Cosmos use a free port and stop it themselves.
- `nimble checkFast` runs the tests that don't start anything, in under a minute.
- A test expected to fail is listed with its reason. If it starts passing, the check
  fails until the list is updated, so the list can't go out of date.
- A phase counts as complete only after its tests pass.
- `cosmos startapp` creates a Thing that loads with no edits.
- `STATUS.md` always shows the current state, the active phase and the next tasks.
- Each phase's requirements fit on one page.
- "Neurodivergent (ND)" is spelled out on first use in every file.
- The target is Windows 11 with Nim 2.0.8.
- Windows-specific code stays in one layer, so Linux and BSD can follow later.

**Source:** MVP-GATE-1 to 5, MVP-DX-1 to 4, MVP-PLAT-1 and 2. Spec §8.

---

## What is left out

**Removed from the design for good:**

- Things passing settings down to the Things inside them.
- A code-based Concept overriding a written one. There is now one form.

**Not in the first version, but may come later:**

| Left out | Reason |
|---|---|
| Encryption | One user, so there is nobody to protect against yet. |
| Licensing | Not needed for personal use. |
| Installer and releases | One machine. Built from source. |
| The dynamic scanner | Not needed to build Things. The `scan` command stays. |
| Other data formats | JSON only means one less decision. |
| Other languages for code | The three-channel rule is already set. |
| References | Decide when real Things need them. |
| World Ledger claims | Not needed for navigation. |
| Delegation and specialists | They keep working, but aren't tested for this version. |
| Memory categories and limits | They keep working, but aren't tested for this version. |
| Extra console commands | Not needed for the main workflow. |
| Multiple instances | One instance is enough. |
| BSD, macOS, Haiku and old toolchains | Built and tested on Windows first. Linux and BSD are the likely places to deploy it. |
| Speed targets | Measure once it is stable. |
| A web interface (REST) | It can be added later on the same command channel. |
| Running in the background | The terminal window is simpler and leaves nothing behind. |

**Source:** Requirements, Retired and Deferred. Spec §3.2, §4A.

---

## The order of work

| Phase | What it does | Status of the plan |
|---|---|---|
| **1. Trustworthy tests** | Bring every test into the check. | Done |
| **2. Commands and AI access** | Connect the running Cosmos, commands and AI tools to the real runtime. | Committed |
| **3. The building loop** | Concepts, waves, wires and the three-command test. | Committed |
| **4. Close the gaps** | Add the remaining missing tests. | Only when a project needs it |
| **Reference deployment** | Run Cosmos as an always-on service. See [the plan](MVP-PLAN.md#reference-deployment). | Only when a project needs a server |

**Limits that apply to every phase:**

- Keep Cosmos in service of building real things. Phase 4 doesn't happen for its own
  sake.
- Measure real audio delay before setting any targets for it.
- The first audio goal is small: one oscillator played from a MIDI keyboard, with its
  delay measured.
- A synth and a MIDI editor are the target. A DAW is only a "possibly".
- Nothing about audio goes in this project.

**Source:** Spec §1, §9.

---

## Still undecided

Nothing in the documents is marked undecided. These questions were found on 2026-11-08
by reading them closely and checking the code. Each one would force a builder to guess.

The eight questions Phase 2 needed were decided on 2026-11-08 and are now part of this
guide.

### Needed for Phase 3

1. **How does Cosmos run a Thing's code?** The documents say the code is Nim and runs
   inside Cosmos. Nim is compiled ahead of time, and nothing in Cosmos today can load
   compiled code while it runs. This is the biggest open question.
2. **Does a simple Thing need code?** One rule says a Concept with no parts needs code.
   Another says a new Thing needs only WHO, VERSION and WHY.
3. **How does a built-from-parts Concept connect to its own inputs and outputs?** The
   wire format can name its parts, but it can't name the Concept itself.
4. **What happens when a wave passes through a built-from-parts Concept?** It has no
   code to forward the wave. The documents don't say how it passes through, or whether
   that costs an extra frame.
5. **What does a PARTS entry look like?** The wire format is written down. The parts
   format isn't.
6. **Can you make two Things from one Concept?** Both would get the same address,
   `cosmos.<WHO>`.
7. **Where does a Thing's rhythm go, and what is the default?** The older documents put
   it in WHEN. The MVP documents don't say, and a new Thing doesn't have to state one.
8. **What shape does a sense expect?** A sense only names a wave. Two Things could send
   waves with the same name and different shapes, and a Thing sensing that name would
   receive both. Each wave matches its sender's declaration, but it may not be what the
   receiver expects. Suggested answer: a sense also states the shape it accepts, and
   Cosmos doesn't deliver a wave of a different shape.

### Housekeeping

9. Both technical documents are marked "Draft for review". That stays correct until
   the questions above are answered.
10. The Phase 2 steps in [the plan](MVP-PLAN.md) aren't written yet.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
