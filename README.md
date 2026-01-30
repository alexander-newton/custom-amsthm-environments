# Custom AmSThm Environments Extension for Quarto

Quarto has excellent built-in support for standard theorem-like environments (theorem, lemma, corollary, etc.), but currently doesn't provide a way to define custom amsthm environments like "Problem", "Claim", or "Observation". This extension fills that gap by allowing you to define custom theorem-like environments that work seamlessly with both HTML and LaTeX output.

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
- **`numbering-style`**: `"section"` (default) or `"global"`

## Examples and Usage

For complete examples, configuration options, and usage patterns, see [example.qmd](example.qmd).

## Features

- Works with both HTML and LaTeX output
- Compatible with Quarto's built-in amsthm environments
- Automatic cross-referencing support
- Configurable numbering styles

