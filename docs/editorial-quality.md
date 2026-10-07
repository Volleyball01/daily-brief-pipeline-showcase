# Editorial Quality: External Knowledge Behind the Brief

A daily brief is not "an LLM plus a news search". Its core behavior sits on six mature fields of knowledge. This page records the few principles the production system takes from each field, with public sources.

These principles shape the maintainer's design. They are **not** six long policies that the production Agent reads every morning:

```text
research → design principle → compact production signal
```

> The maintainer knows a lot; the production Agent sees little.

The private research notes behind this page are longer and stay private. Only the distilled principles and their public sources are published here.

## 1. Agent context engineering

- **Give the model the smallest set of high-signal tokens.** Irrelevant text degrades reasoning well below the context limit. Relevant information works best at the start or the end of the prompt, and adherence drops as the number of simultaneous instructions grows. So the mission and the editorial standard come first, and engineering detail stays out of the normal path. [Levy, Jacoby & Goldberg 2024][same-task]; [Liu et al. 2024][lost-middle]; [Jaroslawicz et al. 2025][ifscale]; [Anthropic: Effective context engineering][ctx-eng]
- **Disclose progressively, and let code do deterministic work.** Dates, paths, config subsets, deduplication windows, and structural checks are computed by scripts. Exception guidance loads only when the exception occurs. Between chained steps, use programmatic gates rather than a second model reviewer. [Anthropic: Agent Skills][skills]; [Anthropic: Building effective agents][effective-agents]
- **Evaluate the output, not the path.** Engineering tests prove contracts, not that the brief is good. Quality needs its own evaluation of the finished product. [Anthropic: Demystifying evals][evals]

## 2. Journalism and editorial practice

- **A briefing is curation, not a compressed front page.** Choose what this reader genuinely needs to know before the day starts. Major public news is included whether or not it matches stated interests.
- **"Update me" is not enough.** Across 47 markets, "update me" is the need that people think the news media serve best. The top priority, where importance most exceeds perceived performance, is news that helps people understand, especially news that *gives them perspective*. So each item is a short, complete paragraph: what happened, the key fact, why it matters today, and what to watch next where relevant. [Reuters Institute DNR 2024: user needs][risj-user-needs]
- **Short is not the same as thin.** Density comes from removing redundancy, not meaning.

## 3. Weather and risk communication

- **Say what the weather will do, not only what it will be.** Translate forecasts into impact on the reader's day: when to carry an umbrella, the temperature swing, and real warnings. Do not invent risk on a calm day. [WMO impact-based forecast and warning services][wmo-ibf]
- **A probability needs its reference.** People misread "30 % rain" mainly because they do not know which period or area it refers to. So precipitation is tied to a time window and a concrete suggestion. [Gigerenzer et al. 2005][gigerenzer]

## 4. Information design

- **Readers scan first.** Use a bold lead, put the conclusion first, keep one idea per paragraph, and keep the brief finishable in a few minutes. [NN/g: Concise, scannable, objective][nng-scannable]; [NN/g: Inverted pyramid][nng-pyramid]

## 5. Personalization

- **Reader context is a tie-breaker, not a filter.** Optimizing only for interest similarity narrows coverage, diversity, and public-interest news. A small, non-sensitive reader profile breaks ties between items of equal news value and shapes the angle of explanation. It never fills quotas by interest tag, and it never guesses at the reader's private state. [Helberger 2019][helberger]; [Kaminskas & Bridge 2016][kaminskas]

## 6. Behavioral science

- **Keep the closing note low-pressure and specific.** Controlling language ("should", "must") invites reactance; concrete wording reduces it. Generic positive self-statements can backfire for the people who most "need" them. So the note offers one specific, situational cue rather than a slogan. [Miller et al. 2007][miller]; [Wood, Perunovic & Lee 2009][wood]

## Fidelity: a review item, not a new gate

Proper names, numbers, and dates carried from verified evidence must remain accurate; translation or transliteration must not change the underlying entity or fact. Explanation may add perspective; it must not alter facts.

Fidelity is a focus for the **offline editorial benchmark** and for the owner's review of real briefs. It deliberately does **not** add a production LLM reviewer, and it does not grow the runtime context. The deterministic finalize step already confirms mechanically that every verified news item reaches the brief. Wording-level fidelity is judged offline.

## Maintenance rule: research before changing core behavior

Before changing how the brief selects, explains, personalizes, formats, or speaks, the maintainer first consults the relevant field above. The process:

1. name the field the change touches;
2. read primary or authoritative sources, or mature product practice;
3. distill a few principles that apply directly to this product;
4. record them in the maintenance documents;
5. only then change prompts, pipeline, or evaluation;
6. judge the change by the quality of real output, not only by engineering tests.

Research stays in maintenance context. It is never turned into "read the papers before every morning run".

[same-task]: https://aclanthology.org/2024.acl-long.818/
[lost-middle]: https://aclanthology.org/2024.tacl-1.9/
[ifscale]: https://arxiv.org/abs/2507.11538
[ctx-eng]: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
[skills]: https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
[effective-agents]: https://www.anthropic.com/engineering/building-effective-agents
[evals]: https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents
[risj-user-needs]: https://reutersinstitute.politics.ox.ac.uk/digital-news-report/2024/more-just-facts-how-news-audiences-think-about-user-needs
[wmo-ibf]: https://reliefweb.int/report/world/wmo-guidelines-multi-hazard-impact-based-forecast-and-warning-services-part-ii-putting
[gigerenzer]: https://doi.org/10.1111/j.1539-6924.2005.00608.x
[nng-scannable]: https://www.nngroup.com/articles/concise-scannable-and-objective-how-to-write-for-the-web/
[nng-pyramid]: https://www.nngroup.com/articles/inverted-pyramid/
[helberger]: https://www.ivir.nl/publicaties/download/On-the-Democratic-Role-of-News-Recommenders.pdf
[kaminskas]: https://research.ucc.ie/en/publications/diversity-serendipity-novelty-and-coverage-a-survey-and-empirical/
[miller]: https://doi.org/10.1111/j.1468-2958.2007.00297.x
[wood]: https://contextualscience.org/publications/wood_perunovic_lee_2009
