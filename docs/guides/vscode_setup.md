# VS Code Setup

If you are using Visual Studio Code, there are a couple of things that you can do to smooth out the workflow of running and updating your tests.

## Custom tasks for testing

VS Code supports [custom tasks](https://code.visualstudio.com/Docs/editor/tasks#_custom-tasks), which allow you to, among other things, run command-line tools using editor-contextual information like the project you're working on, the file you're in, or the line you're on.
Custom tasks are accessible by running the command `Tasks: Run Task`, but can also be bound to keyboard shortcuts (see below).

I personally use three custom tasks for testing:

  * `Run tests` - `mix test`
  * `Run stale tests` - `mix test --stale`
  * `Run tests in current file` - `mix test FILE`
  * `Run test at cursor` - `mix test FILE:LINE`

To set these up:

  1. Run the command `Tasks: Open User Tasks`. This will open your global `tasks.json` that will apply to all projects. (You can optionally use a local `.vscode/tasks.json` file per-project.)
  2. Add the three tasks below and save the file.

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Run tests",
      "type": "shell",
      "command": "mix",
      "args": ["test"],
      "options": {
        "cwd": "${workspaceFolder}"
      },
      "presentation": {
        "focus": true
      },
      "group": "test"
    },
    {
      "label": "Run stale tests",
      "type": "shell",
      "command": "mix",
      "args": ["test", "--stale"],
      "options": {
        "cwd": "${workspaceFolder}"
      },
      "presentation": {
        "focus": true
      },
      "group": "test"
    },
    {
      "label": "Run tests in current file",
      "type": "shell",
      "command": "mix",
      "args": ["test", "${relativeFile}"],
      "options": {
        "cwd": "${workspaceFolder}"
      },
      "presentation": {
        "focus": true
      },
      "runOptions": {
        "reevaluateOnRerun": false
      },
      "group": "test"
    },
    {
      "label": "Run test at cursor",
      "type": "shell",
      "command": "mix",
      "args": ["test", "${relativeFile}:${lineNumber}"],
      "options": {
        "cwd": "${workspaceFolder}"
      },
      "presentation": {
        "focus": true
      },
      "runOptions": {
        "reevaluateOnRerun": false
      },
      "group": "test"
    }
  ]
}
```

Once saved, these tasks should immediately be available through `Tasks: Run Task` or `Tasks: Run Test Task`.

## Keyboard shortcuts

To assign keyboard shortcuts to the three tasks created above:

  1. Run `Preferences: Open Keyboard Shortcuts (JSON)`.
  2. Add the shortcuts below and save the file.

```json
{
  "key": "ctrl+space a",
  "command": "workbench.action.tasks.runTask",
  "args": "Run tests"
},
{
  "key": "ctrl+space s",
  "command": "workbench.action.tasks.runTask",
  "args": "Run stale tests"
},
{
  "key": "ctrl+space f",
  "command": "workbench.action.tasks.runTask",
  "args": "Run tests in current file"
},
{
  "key": "ctrl+space c",
  "command": "workbench.action.tasks.runTask",
  "args": "Run test at cursor"
},
```

The shortcuts above represent my own personal preferences and can be replaced with whatever you'd prefer.

## Integrating `mix mneme.watch`

In addition to the tasks and keyboard shortcuts above, you may want to add some tasks that use `mix mneme.watch`.

```json
{
  "label": "Watch stale tests",
  "type": "shell",
  "command": "mix",
  "args": ["mneme.watch", "--stale"],
  "options": {
    "cwd": "${workspaceFolder}"
  },
  "presentation": {
    "focus": false
  },
  "group": "test"
},
{
  "label": "Watch tests in current file",
  "type": "shell",
  "command": "mix",
  "args": ["mneme.watch", "${relativeFile}"],
  "options": {
    "cwd": "${workspaceFolder}"
  },
  "presentation": {
    "focus": false
  },
  "runOptions": {
    "reevaluateOnRerun": false
  },
  "group": "test"
},
{
  "label": "Watch test at cursor",
  "type": "shell",
  "command": "mix",
  "args": ["mneme.watch", "${relativeFile}:${lineNumber}"],
  "options": {
    "cwd": "${workspaceFolder}"
  },
  "presentation": {
    "focus": false
  },
  "runOptions": {
    "reevaluateOnRerun": false
  },
  "group": "test"
},
```

Along with their keyboard shortcuts:

```json
{
  "key": "ctrl+space w s",
  "command": "workbench.action.tasks.runTask",
  "args": "Watch stale tests"
},
{
  "key": "ctrl+space w f",
  "command": "workbench.action.tasks.runTask",
  "args": "Watch tests in current file"
},
{
  "key": "ctrl+space w c",
  "command": "workbench.action.tasks.runTask",
  "args": "Watch test at cursor"
},
```
