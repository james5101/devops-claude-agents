# DevOps Architecture Skills for GitHub Copilot

This directory contains Copilot skills converted from the original Claude Code agents.

## Skills Included

- `architecture-designer` - Front door for greenfield platform-architecture design
- `architecture-reviewer` - Critiques platform-level cloud architecture
- `aws-architect` - AWS platform-architecture specialist
- `azure-architect` - Azure platform-architecture specialist
- `gcp-architect` - GCP platform-architecture specialist
- `design-architecture` - Kick off greenfield design workflow
- `review-architecture` - Review design or implementation

## Installation

Run the install script to copy skills to your user profile:

```batch
install-skills.bat
```

Or manually copy the skill folders to `%USERPROFILE%\.agents\skills\`

Restart VS Code after installation for Copilot to load the skills.

## Publishing as Packages

To make these skills available to others, publish each as a separate GitHub repository with just the `SKILL.md` file. Users can then install via:

```bash
npx skills add https://github.com/your-org/skill-name
```