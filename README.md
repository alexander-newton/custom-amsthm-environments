# Custom AmSThm Environments Extension for Quarto

Quarto has excellent built-in support for standard theorem-like environments (theorem, lemma, corollary, etc.), but currently doesn't provide a way to define custom amsthm environments like "Problem", "Claim", or "Observation". This extension fills that gap by allowing you to define custom theorem-like environments that work seamlessly with both HTML and LaTeX output.

## Key Feature: Continuous Numbering

**All custom environments automatically share the same counter**, providing continuous numbering across different environment types within sections. For example, you might see:

- Problem 1.1
- Example 1.2
- Corollary 1.3
- Axiom 1.4

Where all environments use the same sequential numbering scheme.

## Installation

```bash
quarto add alexander-newton/custom-amsthm-environments
```

## Quick Start

Define custom environments in your YAML frontmatter:

```yaml
---
title: "My Document"
custom-amsthm:
  - key: prm
    name: Problem
  - key: clm
    name: Claim
    numbering-style: global
  - key: nota
    name: Notation
    numbered: false
filters:
  - custom-amsthm-environments
---
```

Use them in your document:

```markdown
::: {#prm-problem1}
Show that $2 + 2 = 4$.
:::

See @prm-problem1 for details.
```

## Configuration

Each environment requires:
- **`key`**: Short identifier (e.g., `prm`)
- **`name`**: Display name (e.g., "Problem")

Optional fields (automatically derived if not specified):
- **`reference-prefix`**: Cross-reference text (defaults to `name`)
- **`latex-name`**: LaTeX environment name (defaults to lowercase `name`)
- **`numbered`**: Whether to number (defaults to `true`)

**Important:** Avoid using names that conflict with Quarto's built-in theorem types (`theorem`, `lemma`, `corollary`, `proposition`, `example`, `exercise`, `definition`, `conjecture`, `remark`, `solution`, `proof`). Use unique names like "My Theorem", "Problem", "Claim", etc.

## Examples and Usage

For complete examples, configuration options, and usage patterns, see [example.qmd](example.qmd).

## Features

- Works with both HTML and LaTeX output
- Compatible with Quarto's built-in amsthm environments
- Automatic cross-referencing support
- Configurable numbering styles

