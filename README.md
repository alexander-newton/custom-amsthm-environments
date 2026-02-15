# Custom AmSThm Environments for Quarto

A Quarto extension for defining custom theorem-like environments with automatic continuous numbering across all environment types.

## Installation

```bash
quarto add alexander-newton/custom-amsthm-environments
```

## Basic Usage

Define custom theorem environments in your document's YAML frontmatter:

```yaml
---
title: "Document Title"
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

Use environments in your document:

```markdown
::: {#prm-first}
Show that $2 + 2 = 4$.
:::

::: {#axm-choice}
##### Axiom of Choice
Every set has a choice function.
:::
```

Output:
- Problem 1
- Axiom 2 (Axiom of Choice)

## Configuration

### Required Fields

| Field | Description | Example |
|-------|-------------|---------|
| `key` | Short identifier for div IDs | `prm` |
| `name` | Display name in output | `Problem` |

### Optional Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `numbered` | boolean | `true` | Enable/disable numbering |
| `reference-prefix` | string | `name` | Prefix used in cross-references |
| `latex-name` | string | `key` | LaTeX environment name |
| `style` | string | `"plain"` | amsthm style: `plain` (italic), `definition` (upright), `remark` (upright, lighter) |

### Document-Level Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `custom-amsthm-counter-sharing` | string | `"shared"` | Counter mode: `shared` (all types share one counter) or `independent` (each type has its own counter) |

### Configuration Examples

```yaml
custom-amsthm:
  # Minimal configuration
  - key: prm
    name: Problem

  # Unnumbered environment
  - key: nota
    name: Notation
    numbered: false

  # Custom LaTeX environment name
  - key: obs
    name: Observation
    latex-name: customobs

  # Custom reference prefix
  - key: axm
    name: Axiom
    reference-prefix: Ax

  # Theorem style (plain = italic, definition = upright, remark = lighter)
  - key: mydef
    name: Definition
    style: definition
```

#### Independent Counters

By default, all environments share a single counter. To give each environment type its own counter:

```yaml
custom-amsthm-counter-sharing: independent
custom-amsthm:
  - key: mythm
    name: Theorem
  - key: mydef
    name: Definition
    style: definition
  - key: myaxm
    name: Axiom
```

With `independent` mode:
- Theorem 2.1, Theorem 2.2
- Definition 2.1, Definition 2.2
- Axiom 2.1

Each counter resets per section independently.

### Important: LaTeX Name Generation

By default, `latex-name` is set to the `key` value to avoid conflicts with Quarto's built-in theorem types (theorem, lemma, definition, corollary, etc.).

**Do not use keys that match built-in types:**
- Avoid: `thm`, `lem`, `def`, `cor`, `prop`, `exm`, `exr`
- Use: `mythm`, `mylem`, `mydef`, `mycor`, `prm`, `axm`, `obs`, `clm`

If you need a specific LaTeX environment name, set it explicitly:

```yaml
custom-amsthm:
  - key: mydef
    name: Definition
    latex-name: customdefinition
```

## Features

### Continuous Numbering (Default)

All custom environments share a single counter. In PDF output, built-in Quarto theorem types also share this counter. This is the default behavior (`custom-amsthm-counter-sharing: shared`).

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

Output:
- Problem 1
- Axiom 2
- Problem 3

### Independent Numbering

Each environment type gets its own counter, numbered by section. Set `custom-amsthm-counter-sharing: independent` in your YAML frontmatter.

```markdown
::: {#mythm-first}
First theorem.
:::

::: {#mydef-first}
First definition.
:::

::: {#mythm-second}
Second theorem.
:::
```

Output:
- Theorem 1.1
- Definition 1.1
- Theorem 1.2

Override numbers work correctly in independent mode, using the per-environment counter:

```markdown
::: {#myaxm-special number="A1"}
##### Foundational Axiom
Special axiom.
:::
```

### Custom Numbering Override

Assign custom numbers that do not affect sequential numbering:

```markdown
::: {#axm-standard}
Standard axiom.
:::

::: {#axm-special number="A1"}
##### Foundational Axiom
Uses custom number A1.
:::

::: {#axm-next}
Next axiom.
:::
```

Output:
- Axiom 1
- Axiom A1 (Foundational Axiom)
- Axiom 2

Non-numeric override values suppress the number:

```markdown
::: {#axm-choice number="Axiom of Choice"}
Every set has a choice function.
:::
```

Output:
- Axiom of Choice

### Titles

Add optional titles using level-5 headers (`#####`):

```markdown
::: {#prm-hard}
##### Challenging Problem
Prove P ≠ NP.
:::
```

Output:
- Problem 1 (Challenging Problem)

### Cross-References

Reference custom environments using standard Quarto syntax:

```markdown
According to @axm-choice, we can derive @prm-first.
```

**LaTeX/PDF output:**
- Renders as: "According to Axiom 1, we can derive Problem 2."
- Creates clickable hyperlinks

**HTML output:**
- Renders as: "According to Axiom 1.1, we can derive Problem 1.2."
- Creates clickable links

Cross-references use the `reference-prefix` field (defaults to `name`).

## Output Format Differences

### LaTeX/PDF

- Section-based numbering: Theorem 1.1, Problem 1.2, Axiom 2.1
- Continuous numbering across all environment types, including Quarto built-ins
- All theorems, definitions, lemmas, custom environments share one counter

### HTML

- Section-based numbering: Theorem 1.1, Problem 1.2, Axiom 2.1
- Custom environments share one counter
- Quarto built-in types (theorem, definition, lemma) use separate counters
- Enable section-based numbering for built-ins with `crossref: chapters: true`

Example with `number-sections: true`:

```yaml
---
format: html
number-sections: true
crossref:
  chapters: true  # Optional: enables section-based numbering for built-ins
custom-amsthm:
  - key: prm
    name: Problem
---
```

## Integration with Quarto Built-ins

Custom environments work alongside Quarto's standard theorem types:

```markdown
::: {#thm-pythagoras}
##### Pythagorean Theorem
In a right triangle, $a^2 + b^2 = c^2$.
:::

::: {#prm-verify}
Verify for a 3-4-5 triangle.
:::
```

**PDF output:** Theorem 1.1, Problem 1.2 (shared counter)
**HTML output:** Theorem 1.1, Problem 1.1 (separate counters)

## Testing

### Running Tests

The extension includes a Python-based test suite. Tests verify output for both HTML and LaTeX formats.

```bash
# Run all tests
cd tests
python run-tests.py

# Run tests for specific project
python run-tests.py features
python run-tests.py book
python run-tests.py article
```

### Test Structure

Tests are defined in `tests/expected/` directory:

```
tests/
├── expected/
│   ├── features-test-continuous-numbering-html.txt
│   ├── features-test-continuous-numbering-tex.txt
│   └── ...
├── features/
│   ├── test-continuous-numbering.qmd
│   └── ...
└── run-tests.py
```

Each expected file contains test cases marked with `=== test-id ===`:

```
=== latex-name-uses-key ===
\newtheorem{mydef}

=== crossref-resolved ===
\hyperref[mydef-first]{Definition~\ref*{mydef-first}}
```

### Adding Tests

1. Create a `.qmd` file in the appropriate test directory (e.g., `tests/features/`)
2. Create expected output files in `tests/expected/`:
   - `{project}-{filename}-html.txt` for HTML output
   - `{project}-{filename}-tex.txt` for LaTeX output
3. Define test cases using `=== test-id ===` markers
4. Run tests to verify

## Error Handling

### Duplicate Override Numbers

The extension detects and reports duplicate override numbers:

```markdown
::: {#axm-first number="A1"}
First axiom.
:::

::: {#axm-second number="A1"}
Second axiom.
:::
```

Error: `Duplicate override number 'A1' for environment type 'Axiom'`

### Unresolved Cross-References

HTML output warnings appear when cross-references cannot be resolved:

```
WARNING: Unable to resolve crossref @prm-missing
```

Ensure referenced IDs exist and use the correct `key` prefix.

## Troubleshooting

### Environments not rendering

1. Verify filter is specified: `filters: - custom-amsthm-environments`
2. Check ID format uses correct key: `#prm-first` not `#first`
3. Confirm extension installation: `quarto list extensions`

### PDF rendering hangs

Ensure LaTeX environment names do not contain spaces. The extension automatically handles this by using the `key` value for `latex-name`.

### Cross-references show as `@ref-id`

For LaTeX/PDF output, ensure the extension is up to date. Cross-reference resolution was added in recent versions.

For HTML output, this may indicate the custom environment was not properly processed. Verify the filter is loaded and the environment key matches the ID prefix.

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
##### First Axiom
Every set is well-defined.
:::

::: {#prm-basic}
Show that the empty set exists.
:::

::: {#axm-choice number="AC"}
##### Axiom of Choice
Every set has a choice function.
:::

::: {#nota-symbols}
Let $\emptyset$ denote the empty set.
:::

::: {#prm-hard}
##### Challenge Problem
Prove the continuum hypothesis.
:::

According to @axm-first, we can address @prm-basic.
```

**PDF Output:**
- Axiom 1.1 (First Axiom)
- Problem 1.2
- Axiom AC (Axiom of Choice)
- Notation (unnumbered)
- Problem 1.3 (Challenge Problem)
- "According to Axiom 1.1, we can address Problem 1.2."

## Example Documents

See `tests/features/` for complete working examples:
- `test-continuous-numbering.qmd` - Continuous numbering demonstration
- `test-independent-counters.qmd` - Independent counter mode
- `test-independent-override.qmd` - Override numbers in independent mode
- `test-mixed-numbering.qmd` - Integration with Quarto built-in types
- `test-override-numbering.qmd` - Custom number override features
- `test-latex-name-and-crossref.qmd` - LaTeX naming and cross-references
- `test-theorem-style.qmd` - Theorem style options (plain, definition, remark)

## Contributing

Submit issues and pull requests at [github.com/alexander-newton/custom-amsthm-environments](https://github.com/alexander-newton/custom-amsthm-environments)

## License

MIT License

## Credits

Based on [MateusMolina/custom-amsthm-environments](https://github.com/MateusMolina/custom-amsthm-environments) with enhancements for continuous numbering, cross-reference resolution, and override numbering features.
