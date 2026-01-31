 # Introducing Kiro
[Kiro](https://kiro.dev/) is an AI-powered IDE designed specifically for building production-ready agents. It bridges the gap between rapid prototyping and production deployment through a structured development approach.

In this workshop, you'll experience Kiro's complete workflow:

Rapid Prototyping: Start with "vibe coding" to quickly build and test agent concepts
Structured Development: Use Kiro Specs to create requirements, design, and implementation plans

# kiro vs kiro cli

Kiro and [Kiro CLI](https://kiro.dev/cli/) are two forms of the same tool:

Kiro — a full IDE with a graphical interface where I work as your AI assistant. It has a code editor, visual chat, panels, file explorer, terminal, diagnostics — everything in one window.

Kiro CLI — a command-line interface for working with me through the terminal. Same AI functionality, but no GUI — just text commands and responses.

Simply put: Kiro is an app with windows and buttons, Kiro CLI is terminal-based commands.

## Key Kiro Features

**Privacy First**: [Keep code secure with privacy controls.](https://kiro.dev/docs/privacy-and-security/)

**Vibe Mode**: Chat-driven development for rapid prototyping and exploration


**Spec Mode**: Structured approach with requirements gathering, design planning, and task breakdown


**MCP Integration**: Native support for Model Context Protocol servers and tools


**Agent Hooks**: Event-driven automations that trigger on file changes or user actions


**Autonomous Execution**: Let Kiro handle implementation tasks while you focus on architecture

**Powers**: [Powers](https://kiro.dev/powers/) add specialized context and tools to the Kiro agents on-demand. No more MCP context overload.


# Installation

## [Download Kiro](https://kiro.dev/)

# [Authentication](https://kiro.dev/docs/getting-started/authentication/)

Kiro supports the following authentication providers:

**GitHub**: Seamless integration with your GitHub account


**Google**: Sign in with your Google credentials


**AWS Builder ID**: Quick setup for individual developers


**AWS IAM Identity Center**: Enterprise-grade authentication

# [Pricing](https://kiro.dev/pricing/)


# kiro settings


|                       **parametr**                       | **value**    | **description**                                                                                                                                                                                             |
|:--------------------------------------------------------:|:-------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [Agent Autonomy](https://kiro.dev/docs/chat/autopilot/)  | Autopilot , Supervised | Autonomy determines whether the agent will ask for accept/reject at each checkpoint in the workflow.                                                                                                        |
| [Trusted Commands](https://kiro.dev/docs/chat/terminal/) |  | Shell commands to auto-accept if requested by the Agent.                                                                                                                                                    |
|                     Command Denylist                     | | String patterns to deny auto-approval and require user review, even if they match trusted commands. Commands containing any of these patterns will always require manual approval.                          |
|                    Agent Ignore Files                    |  | Ignore pattern files that Kiro Agent should respect when reading workspace files. These files contain patterns for files and directories that should be excluded from agent read operations. Ex: .gitignore |

