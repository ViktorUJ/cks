# Design: Legacy labs 02 and 03 localization

## Source and ownership

`tasks/eks/labs/02/README_RUS.MD` and `tasks/eks/labs/03/README_RUS.MD` are the semantic sources. One language-specific translation agent owns one target README at a time; translations are executed in two parallel lab waves to avoid overlapping file writes.

## Navigation model

The language selector is an eight-language set ordered RU, EN, ES, FR, DE, GE, TW, JP. Each file links to the other seven variants. Labels are: `Русская версия`, `Eng version`, `Versión en español`, `Version française`, `Deutsche Version`, `ქართული ვერსია`, `繁體中文版`, and `日本語版`. Russian references retain the legacy `README_RUS.MD` name.

Course index documents and chapter 12, 13, and 35 documents select the README variant matching their own language. Existing EN/RU fallback links are replaced where required by that policy.

## Safety boundaries

No content is added to change Kubernetes/AWS behavior. Commands, identifiers, resource names, URLs, paths, code fences, configuration values, and version/CIDR values remain unchanged. No new reverse `Chapter_Reference` links are created because labs 02 and 03 do not use that pattern.

## Validation

Validate file existence; selector completeness and target existence; all course references to labs 02/03; Markdown structure including headings, code fences, tables, and Mermaid blocks/styles; technical literal preservation; and available Markdown diagnostics.
