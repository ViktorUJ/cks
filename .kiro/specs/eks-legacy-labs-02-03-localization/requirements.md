# Requirements: Localize legacy EKS labs 02 and 03

## Objective
Provide complete Spanish, French, German, Georgian, Traditional Chinese, and Japanese versions of the legacy EKS labs `02` and `03`, using each Russian README as the semantic source. Ensure the course navigation resolves every lab reference to a README in the language of the referring course page.

## Functional requirements

1. Create these full translations for each lab: `README_ES.MD`, `README_FR.MD`, `README_DE.MD`, `README_GE.MD`, `README_TW.MD`, and `README_JP.MD`.
2. Preserve executable and technical literals exactly: commands, URLs, paths, resource names, API paths, YAML/JSON keys and values, versions, CIDRs, and code blocks.
3. Translate user-facing prose, headings, table labels, descriptions, warnings, tips, comments, and Mermaid labels.
4. Each of the 16 README files in each localized lab set (EN, RU, and six new locales across both labs) must expose a seven-link language switcher. It must use the canonical order RU, EN, ES, FR, DE, GE, TW, JP; omit the current language; use `README_RUS.MD` for Russian; and use the established labels.
5. Update every course index and chapter 12, 13, and 35 reference to labs 02 and 03 so that its README suffix matches the referring document language. English targets `README.MD`; Russian targets `README_RUS.MD`.
6. Do not introduce reverse chapter references into legacy labs 02 or 03, and do not change technical lab behavior.

## Acceptance criteria

- All 12 new files exist and are complete translations based on the matching Russian source.
- Every affected course link exists and targets the matching language.
- Switcher links point only to existing local files and contain exactly seven links.
- Heading, code-fence, table, Mermaid, and technical-literal structure is preserved relative to the Russian source.
