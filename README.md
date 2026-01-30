# Custom AmSThm Environments Extension for Quarto

A Quarto extension that enables custom theorem-like environments (Problem, Claim, Observation, etc.) with **automatic continuous numbering** across different environment types.

## Features

✅ **Continuous Numbering** - All custom environments share the same counter
✅ **Override Numbers** - Use custom numbers like "A1" or "Axiom of Choice"
✅ **HTML & LaTeX Support** - Works seamlessly in both output formats
✅ **Built-in Integration** - Mixes with Quarto's standard theorem types
✅ **Flexible Configuration** - Numbered/unnumbered, custom names, titles

## Installation

```bash
quarto add alexander-newton/custom-amsthm-environments
```

## Quick Start

### Basic Usage

```yaml
---
title: "My Document"
format: pdf
custom-amsthm:
  - key: prm
    name: Problem
  - key: axm
    name: Axiom
filters:
  - custom-amsthm-environments
---
```

```markdown
::: {#prm-first}
Show that $2 + 2 = 4$.
:::

::: {#axm-choice}
## Axiom of Choice
Every set has a choice function.
:::
```

**Output:**
- Problem 1
- Axiom 2 (Axiom of Choice)

### Continuous Numbering Example

All custom environments share the same counter:

```markdown
::: {#prm-first}
First problem.
:::

::: {#axm-first}
First axiom.
:::

::: {#prm-second}
Second problem.
:::
```

**Output:**
- Problem 1
- Axiom 2 (continues from Problem 1!)
- Problem 3 (continuous numbering!)

## Configuration Options

### Required Fields

- **`key`**: Short identifier used in div IDs (e.g., `prm` for `#prm-problem1`)
- **`name`**: Display name shown in output (e.g., "Problem")

### Optional Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `numbered` | boolean | `true` | Whether to show numbers |
| `reference-prefix` | string | `name` | Text used in cross-references |
| `latex-name` | string | lowercase `name` | LaTeX environment name |

### Configuration Examples

```yaml
custom-amsthm:
  # Simple definition
  - key: prm
    name: Problem

  # Unnumbered environment
  - key: nota
    name: Notation
    numbered: false

  # Custom LaTeX name
  - key: obs
    name: Observation
    latex-name: observ
```

## Advanced Features

### Override Numbers

Use custom numbers that don't consume sequential numbering:

```markdown
::: {#axm-first}
Standard axiom.
:::

::: {#axm-special number="A1"}
## Foundational Axiom
This uses custom number A1.
:::

::: {#axm-second}
Another standard axiom.
:::
```

**Output:**
- Axiom 1
- Axiom A1 (Foundational Axiom)
- Axiom 2 (continues from 1, skipping the override!)

### Override with Custom Names

```markdown
::: {#axm-choice number="Axiom of Choice"}
Every set has a choice function.
:::
```

**Output:**
- Axiom of Choice (no number shown)

### Custom Titles

Add optional titles using level-2 headers:

```markdown
::: {#prm-hard}
## A Challenging Problem
Prove P ≠ NP.
:::
```

**Output:**
- Problem 1 (A Challenging Problem)

### Unnumbered Environments

```markdown
::: {#nota-basic}
Let $\mathbb{N}$ denote natural numbers.
:::
```

**Output:**
- Notation (no number)

## Output Format Differences

### LaTeX/PDF Output

- **Section-based numbering**: Problem 1.1, Problem 1.2, Problem 2.1
- **Full continuous numbering**: All environment types (including Quarto built-ins) share the same counter
- **Example**: Theorem 1.1, Problem 1.2, Definition 1.3, Axiom 1.4

### HTML Output

- **Section-based numbering**: Problem 1.1, Problem 1.2, Problem 2.1
- **Custom environments only**: Custom types share a counter, Quarto built-ins have separate counters
- **Example**: Theorem 1.1, Problem 1.1, Definition 1.2, Problem 1.2 (built-ins and custom have separate sequences)

**To enable section-based numbering for built-in types**, add `crossref: chapters: true` to your YAML frontmatter:

```yaml
---
title: "My Document"
format: html
number-sections: true
crossref:
  chapters: true
custom-amsthm:
  - key: prm
    name: Problem
filters:
  - custom-amsthm-environments
---
```

With this configuration, built-in types will also use section-based numbering (Theorem 1.1, 1.2, 2.1, etc.), though they will still have a separate counter from custom types.

## Mixing with Built-in Types

Custom environments work alongside Quarto's built-in theorem types:

```markdown
::: {#thm-pythagoras}
## Pythagorean Theorem
In a right triangle, $a^2 + b^2 = c^2$.
:::

::: {#prm-verify}
Verify this for a 3-4-5 triangle.
:::
```

**PDF Output:**
- Theorem 1.1
- Problem 1.2 (shares counter with theorem!)

**HTML Output:**
- Theorem 1 (Quarto's built-in counter)
- Problem 1 (custom counter)

## Important Notes

### Naming Conflicts

⚠️ **Avoid built-in environment names:**

Don't use: `theorem`, `lemma`, `corollary`, `proposition`, `example`, `exercise`, `definition`, `conjecture`, `remark`, `solution`, `proof`

Instead use: `mythm`, `Problem`, `Claim`, `Observation`, or other unique names.

### Duplicate Override Detection

The extension will error if you use the same override number twice:

```markdown
::: {#axm-first number="A1"}
First axiom.
:::

::: {#axm-second number="A1"}
Second axiom.
:::
```

**Error:** `ERROR: Duplicate override number 'A1' for environment type 'Axiom'`

## Complete Example

```yaml
---
title: "Mathematical Foundations"
format:
  pdf:
    keep-tex: true
  html: default
number-sections: true
custom-amsthm:
  - key: prm
    name: Problem
  - key: axm
    name: Axiom
  - key: nota
    name: Notation
    numbered: false
filters:
  - custom-amsthm-environments
---

# Introduction

::: {#axm-first}
## First Axiom
Every set is well-defined.
:::

::: {#prm-basic}
Show that the empty set exists.
:::

::: {#axm-choice number="AC"}
## Axiom of Choice
Every set has a choice function.
:::

::: {#nota-symbols}
Let $\emptyset$ denote the empty set.
:::

::: {#prm-hard}
## Challenge Problem
Prove the continuum hypothesis.
:::
```

**PDF Output:**
- Axiom 1.1 (First Axiom)
- Problem 1.2
- Axiom AC (Axiom of Choice)
- Notation (unnumbered)
- Problem 1.3 (Challenge Problem)

## Examples and Tests

See the `tests/features/` directory for complete working examples:
- `test-continuous-numbering.qmd` - Continuous numbering demo
- `test-mixed-numbering.qmd` - Mixing with built-in types
- `test-override-numbering.qmd` - Override number features

## Troubleshooting

### Environments not rendering?

1. Check filter is specified: `filters: - custom-amsthm-environments`
2. Ensure IDs start with your `key`: `#prm-first` not `#first`
3. Verify extension is installed: `quarto list extensions`

### Numbers not showing in HTML?

This is expected behavior. Custom environments require this extension to show formatted numbers in HTML. Without it, they appear as plain divs.

### Cross-references not working?

Cross-references for custom types have limited support. Use `@prm-id` syntax, but note that Quarto's crossref system has better support for built-in types.

## Contributing

Issues and pull requests welcome at [github.com/alexander-newton/custom-amsthm-environments](https://github.com/alexander-newton/custom-amsthm-environments)

## License

MIT License - see LICENSE file for details

## Credits

Based on [MateusMolina/custom-amsthm-environments](https://github.com/MateusMolina/custom-amsthm-environments) with enhancements for continuous numbering and override features.
