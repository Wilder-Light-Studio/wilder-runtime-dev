Enhancement: Multi‑Instance Cosmos Daemon Support

Goal:
Enable the Cosmos Runtime to support multiple concurrently running daemon instances,
each with its own IPC endpoint, lifecycle, and ConsoleSession state. The CLI must be
able to discover, attach to, and interact with any running instance without ambiguity.

Requirements:

1. Instance Identity
   - Introduce a stable `InstanceId` type (string).
   - Each daemon process must declare its instance id at startup via:
       cosmos start --instance <id> [--port <p>] [--socket <path>]
   - If no instance id is provided, generate a UUID and persist it.

2. Instance Registry
   - Implement a persistent registry file:
       $COSMOS_HOME/instances.json
   - Each entry contains:
       {
         "instanceId": "...",
         "pid": <int>,
         "ipc": { "socket": "...", "port": <int> },
         "startedAt": "...",
         "status": "running" | "dead"
       }
   - On daemon startup:
       - Write or update its entry.
       - Remove stale entries (pid not alive).
   - On daemon shutdown:
       - Mark its entry as "dead" or remove it.

3. IPC Endpoint Isolation
   - Each daemon instance must expose a unique IPC endpoint:
       - Unix: /tmp/cosmos-<instanceId>.sock
       - Windows: TCP port or named pipe
   - The coordinator_ipc layer must route all requests to the correct endpoint
     based on the instance id provided by the CLI.

4. ConsoleSession Server-Side Ownership
   - Move ConsoleSession state entirely into the daemon.
   - The daemon maintains a map:
       sessionId → ConsoleSession
   - Each CLI attachment creates a new sessionId.
   - ConsoleSession lifecycle:
       - Created on `runtime.attach`
       - Destroyed on disconnect or timeout

5. IPC Methods
   Add or update the following IPC methods:

   - runtime.attach(instanceId) → sessionId
       Creates a new ConsoleSession and returns its session id.

   - runtime.console_dispatch(sessionId, rawCommand: string)
       Forwards a raw console command to the ConsoleSession.dispatch method.

   - runtime.render(sessionId)
       Returns a JSON object:
         {
           "statusBar": "...",
           "scopeLine": "...",
           "promptLine": "..."
         }

   - runtime.instances_list()
       Returns the contents of instances.json.

   - runtime.instances_info(instanceId)
       Returns the metadata for a single instance.

6. CLI Behavior
   - Remove console_main.nim entirely.
   - All console interactions must go through:
       cosmos console --instance <id>
   - CLI flow:
       1. Resolve instance id → IPC endpoint via registry.
       2. Call runtime.attach → sessionId.
       3. Enter render/dispatch loop:
            - print runtime.render(sessionId)
            - read user input
            - send runtime.console_dispatch(sessionId, input)

7. Safety & Isolation
   - No shared state between instances.
   - No cross-instance console sessions.
   - No global runtime state outside instances.json.

Acceptance Criteria:
- Multiple `cosmos start --instance X` processes can run simultaneously.
- `cosmos instances list` shows all running instances.
- `cosmos console --instance X` attaches to the correct daemon.
- ConsoleSession state lives only in the daemon, never in the CLI.
- No interference or leakage between instances.