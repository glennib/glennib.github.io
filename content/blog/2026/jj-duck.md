---
title: jj duck
date: 2026-10-09
extra:
  list_title: 'jj duck. My two favourite tools'
---

Strangely, I've recently become attracted to duckdb.
It's not that I have a great use for it, but I just like it.
I like that it's super fast, has a friendly approach to SQL and to the tool in general.
It's great.
It even has a web-based user interface with a notebook-style editor.
I tried it out on a bunch of toy datasets from its online guides, and then later on some huge datasets from work.
On my humble developer laptop it churns through gigabytes in a couple of hundred milliseconds, and it can even handle 100s of gigabytes in a sensible window.
And it uses all my cores, which I like, because it's nice that my tools exploit the computer I have.
However, I have no good use for it, which is too bad.

Less recently, but infinetly more useful in my daily work, I've also come to discover and love jj.
jj is the version control system that should have been there from the start.
While git has given me plenty, and I learned it almost in and out, situations where I get the tingling feeling of not being completely sure how to solve had a tendency to occur.
Rarer and rarer as I got more proficient, but a conflicted rebase, re-arranging of commits, merging of co-workers' branches into mine, always required a fair bit of concentration.
jj is in some ways simpler than git, in that there are fewer concepts, and simultaneously more powerful.
It achieves this by keeping its features orthogonal to each other, and by being friendly in offering the right switches for almost all situations.
Move commits around?
`jj rebase`.
Move file changes around?
`jj squash`.
And you can always specify exactly how you want things moved.
`--before`, `--after`, `--into`, `--onto`, `--from`, `--to`.
And the friendliest command of them all: `jj undo`.
I like jj so much I built a CLI tool that makes it easier to work with stacked changes and GitHub: <https://github.com/glennib/stakk>.

The other day, I tried to understand something in a legacy application at work.
For some reason I wanted to know who'd been most active recently.
Instead of browsing `jj log`, I wanted to try and query for it using jj.
However, I've not yet mastered the rich revset language jj offers for search purposes, and I'm not about to remember all the different templating options jj offers to print out logs.
Additionally, I wanted a result shown grouped by dates and authors, and I'm not even sure jj can achieve that.
If only I could use SQL...

I used a coding agent to create [duckjj](https://gist.github.com/glennib/e884bbde738281563a7665b963d8eeae).
In a nutshell, this script takes the current repository and dumps its history into an in-memory duckdb database.
It's quite fast (I haven't yet tried it on giant repositories), and places you right inside duckdb's SQL prompt.

```
memory D show tables;
┌──────────────┐
│     name     │
│   varchar    │
├──────────────┤
│ bookmarks    │
│ commit_files │
│ commits      │
│ files        │
│ meta         │
│ ops          │
│ parents      │
│ tags         │
│ trailers     │
└──────────────┘
memory D show table commits;
┌───────────────────────────────────────────────────────────┐
│                          commits                          │
│                                                           │
│ commit_id        varchar                                  │
│ change_id        varchar                                  │
│ description      varchar                                  │
│ subject          varchar                                  │
│ author_name      varchar                                  │
│ author_email     varchar                                  │
│ author_is_bot    boolean                                  │
│ authored_at      timestamp with time zone                 │
│ committer_name   varchar                                  │
│ committer_email  varchar                                  │
│ committer_is_bot boolean                                  │
│ committed_at     timestamp with time zone                 │
│ parents          varchar[]                                │
│ is_merge         boolean                                  │
│ bookmarks        varchar[]                                │
│ tags             varchar[]                                │
│ trailers         struct("key" varchar, "value" varchar)[] │
│ empty            boolean                                  │
│ hidden           boolean                                  │
│ divergent        boolean                                  │
│ conflict         boolean                                  │
│ immutable        boolean                                  │
│ on_remote        boolean                                  │
│ on_trunk         boolean                                  │
└───────────────────────────────────────────────────────────┘
```

Then we can just query:

```sql
select
  date_trunc('day', authored_at)::date as when,
  author_email[:8] as who,
  count(*) as n,
  bar(count(*), 0, 11, 20) as fancy
from commits
where true
  and on_trunk
  and not empty
  and not is_merge
group by all
order by 1 desc, 2;
```

```
┌────────────┬──────────┬───────┬──────────────────────┐
│    when    │   who    │   n   │        fancy         │
│    date    │ varchar  │ int64 │       varchar        │
├────────────┼──────────┼───────┼──────────────────────┤
│ 2025-11-20 │ glenn.bi │     2 │ ███▋                 │
│ 2025-11-19 │ glenn.bi │     4 │ ███████▎             │
│ 2025-11-19 │ glennbit │     1 │ █▊                   │
│ 2025-10-18 │ glennbit │     2 │ ███▋                 │
│ 2025-10-10 │ glennbit │     1 │ █▊                   │
│ 2025-08-24 │ glennbit │     1 │ █▊                   │
│ 2025-08-19 │ glennbit │     6 │ ██████████▉          │
│ 2025-08-05 │ glennbit │     1 │ █▊                   │
│ 2025-08-04 │ glennbit │    11 │ ████████████████████ │
│ 2025-08-03 │ glennbit │    10 │ ██████████████████▏  │
│ 2025-08-02 │ glennbit │    10 │ ██████████████████▏  │
│ 2025-08-01 │ glennbit │     3 │ █████▍               │
│ 2025-07-31 │ glennbit │     7 │ ████████████▋        │
│ 2017-11-15 │ glenn.bi │     5 │ █████████            │
│ 2017-11-03 │ glenn.bi │     1 │ █▊                   │
│ 2017-11-03 │ glennbit │     1 │ █▊                   │
└────────────┴──────────┴───────┴──────────────────────┘
```

To me this was awesome.
I'm far from an SQL expert, but it's really nice to be able to use a familiar query language to search around in a repo's history.
And it's just a quick command away.
I've even added a jj alias:

```toml
# ~/.config/jj/config.toml
[aliases]
duck = ["util", "exec", "--", "duckjj"]
```

This way I can run `jj duck` in any repo.

Aside from the fetch / load script, we don't need to come up with a big schema change to make this duckdb schema work in an organization's collection of repositories.
E.g., by adding `repo` to most of the tables and views, this schema can be used to analyze an organization's code history across all repos.

Now, let me run a revealing query on a repo I do some work in:

```sql
from commits
  select
    date_trunc('month', authored_at)::date as month,
    count(*) as n,
    round(avg((description ilike '%—%')::int) * 100)::int as has_em_dash_pct,
    round(avg(len(description)))::int as avg_commit_length,
  where true
    and author_email ilike '%glenn%'
    and on_trunk
    and not empty
    and not is_merge
  group by all
  order by 1 desc;
```

```
┌────────────┬───────┬─────────────────┬───────────────────┐
│   month    │   n   │ has_em_dash_pct │ avg_commit_length │
│    date    │ int64 │      int32      │       int32       │
├────────────┼───────┼─────────────────┼───────────────────┤
│ 2026-09-01 │     7 │              14 │               509 │
│ 2026-08-01 │    12 │              33 │               481 │
│ 2026-07-01 │     6 │              67 │               922 │
│ 2026-06-01 │   123 │              41 │               912 │
│ 2026-05-01 │    17 │              12 │               443 │
│ 2026-04-01 │    11 │               9 │               399 │
│ 2026-03-01 │    40 │               3 │               248 │
│ 2026-02-01 │    23 │               0 │                91 │
│ 2026-01-01 │    59 │               0 │               152 │
│ 2025-12-01 │    91 │               0 │                75 │
│ 2025-11-01 │    23 │               0 │               303 │
│ 2025-10-01 │   234 │               0 │               109 │
│ 2025-09-01 │    93 │               0 │                72 │
│ 2025-08-01 │     5 │               0 │                97 │
│ 2025-07-01 │     2 │               0 │                40 │
│ 2025-06-01 │   164 │               0 │                49 │
│ 2025-03-01 │   125 │               0 │                52 │
│ 2025-02-01 │    92 │               0 │                65 │
│ 2025-01-01 │    38 │               0 │                71 │
│ 2024-12-01 │   115 │               0 │                59 │
│ 2024-11-01 │   123 │               0 │                65 │
│ 2024-10-01 │   306 │               0 │                50 │
│ 2024-09-01 │   172 │               0 │                57 │
│ 2024-08-01 │   106 │               0 │                45 │
│ 2024-07-01 │    22 │               0 │                22 │
└────────────┴───────┴─────────────────┴───────────────────┘
```
