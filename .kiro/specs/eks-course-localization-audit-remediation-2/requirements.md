# Requirements: EKS Course Localization Audit Remediation 2

## Purpose

Correct verified human-facing English remnants in the Japanese, Traditional Chinese, and Georgian EKS course localizations. The corresponding `ru.md` in every chapter is the semantic source.

## Scope

- Update only the JP, TW, and GE chapter files identified by the supplied audit after confirming the text is human-facing prose, headings, table labels, Mermaid labels, comments, or placeholders.
- Preserve AWS and Kubernetes product/API names, commands, CLI flags, YAML/JSON keys and values, ARNs, CIDRs, exact statuses/errors, resource identifiers, and code.
- Translate English prose in tables, headings, Mermaid node/edge labels, bash comments, and documentation-link captions where appropriate.

## Verified findings

- The reported English labels are present in the cited JP/TW/GE files, including `Validation`, `IaC management`, `cache miss`, and `health check: path/port`.
- `00-5-tools/jp.md` contains the human-facing bash comment `# default region`; retain the command and translate only the comment.
- `16/tw.md` links to `README_TW.MD` for labs 104, 106, and 107. The Markdown permits the documented line breaks and the targets use the matching language, so no link-format change is required.

## Acceptance criteria

1. Confirmed human-facing remnants are localized consistently with the Russian source.
2. No technical literal listed above is altered.
3. Each touched document remains structurally valid Markdown with balanced fenced code/Mermaid blocks and intact table structure.
4. All local lab links resolve and point to a README in the chapter's language.
