---
title: "Inquire"
date: 2025-08-04
updated: 2025-08-19
extra:
  list_title: 'Work sample: Inquire, an analytics user data service for personalization'
---

## TLDR

During 2024 and 2025 I led the design and development of *Inquire*, a centralized user data service powering personalization across more than 100 local newspapers.

- I implemented an entity-attribute-value (EAV) data model to avoid the friction of schema changes and let teams onboard new attributes quickly.
- I built attribute catalogs and an intuitive management dashboard to enable a high degree of self-service and to reduce platform bottlenecks.
- I added metrics to provide data owners with high-resolution insights into usage patterns.
- I integrated user consent data, ensuring that consumers can be confident in data usage compliance.
- I implemented in-flight type checking to guarantee the correctness of delivered data.

## Introduction

I was recently challenged to write about work I was proud of.
This post is an attempt at that.

<aside id="disclaimer">
<p>
This article reflects my personal experiences and opinions as a developer at Amedia.
</p>
</aside>

## Background

At [Amedia](https://www.amedia.no/), we host and develop for more than 100 local newspapers across Norway.
A portion of Amedia's success is owed to partially personalized front pages, along with personalized marketing and communications.
Amedia's backend is a collection of (micro) services called in a variety of situations, e.g., to serve the contents of an article, a front-page teaser, or marketing messages.

Since each page load is partially personalized to the logged-in user, many of the backend services require attributes of the user to function optimally.
Much of this data lives in our data lake, which is not optimized for fast, random-access queries for individual users.

To support in-flight requests for user analytics, Amedia has over the course of several years developed multiple services that host selections of user attributes for fast access.
*Inquire* is the third iteration of a user data service, and was made to address some challenges that were revealed along the way:

<dl class="dl-inline">
<dt>Need for high-resolution usage metrics:</dt>
<dd>
Not having usage metrics on the attribute level left us searching in our codebases for whether an attribute
was used if we wanted to retire it.
Combined with each request returning <em>all</em> user data, it made attribute usage information
hard to find.
</dd>

<dt>Out-of-band consent data:</dt>
<dd>
Whether the user consented to use of attributes for personalized ads, communications, marketing,
or editorial content had to be requested from separate services.
This fragmented setup made life harder for data consumers, who had to piece together user context from
multiple services
</dd>

<dt>Platform bottleneck:</dt>
<dd>
Appending user attributes required significant work for the maintaining platform team.
One column per user attribute implied schema migrations and accompanying application code
changes whenever, e.g., a marketing team wanted to test new personalized messages.
The fast pace of these teams is important for the organization.
</dd>
</dl>

While the previous iterations of the user data services have provided tremendous value for Amedia, Inquire was built to confront the challenges listed above.

## System overview

Inquire consists of a central **Postgres database**, an **HTTP/JSON service** that serves user data to downstream consumers, and a suite of support components:

<dl class="dl-inline">
<dt>Batch ingestion pipeline</dt>
<dd>for periodic loading from the data lake.</dd>

<dt>Stream ingestion pipeline</dt>
<dd>for real-time updates (e.g., user consent).</dd>

<dt>Management dashboard</dt>
<dd>for attribute onboarding and observability.</dd>
</dl>

Almost all user analytics data lives in Google BigQuery and is updated at most daily.
The batch ingest pipeline regularly checks source tables for updates and makes sure that the latest data is imported to the Inquire database.
Other data, such as user consents, are retrieved from message queues via the stream ingestor, immediately following changes to the user's preferences.

I initially wrote the main HTTP/JSON service in Rust, and the support components in Python.
However, since then, all the support services have been migrated to Rust to achieve a homogenous code base for this system.

## Key design decisions and challenges

A selection of key challenges and areas where I had important contributions and learnings.

### Navigating our internal development platform

Amedia was my first job focused on web development.
Coming from a research and robotics background, HTTP, REST, and even databases were new to me.
This made standing up API services both a challenge and a learning opportunity.
At Amedia, we can move fast and spin up backends quickly to solve narrow problems.
This also means that cohesion and uniformity have not always been the main priorities.
The GitHub organization has close to a thousand repositories in <span title="In my very short investigation, I found the following languages: Python, Rust, Go, Kotlin, Java, Javascript, Clojure, Swift, Typescript, Dart, Scala, Php, Ruby.">more than 13 languages(!)</span>.

As the sole developer on our data platform team with the time and motivation for developing API services (at least at the time), moving from task to deployment was a big learning opportunity.
Especially since most of the concepts were new to me.
When I started this work, much of the knowledge needed to deploy a service was distributed among the many teams, and a central guide or a "golden path" did not exist.
I worked closely with the IDP team to debug unclear parts of the deployment pipeline and smooth over internal friction.
Their responsiveness and willingness to collaborate were instrumental.

### Flexible data modeling with EAV

A key design choice in Inquire is an entity-attribute-value data model.
Data is stored in a table with columns for user ID, attribute ID which references an attribute catalog, metadata describing when data was updated and when it becomes stale, and the data value itself, stored as JSON.
The attribute catalog contains a human-readable name and expected type information.
This lets us avoid constant schema migrations and unblock teams who wanted to test new attributes quickly.

### Consent integration

In addition to the main data table and the attribute catalog, we have a table describing data usage *purposes*, where we can map user consent to attributes.
A user opts in to or out of separate purposes, so the same attribute for a given user may be available under the *editorial* purpose but will be `null` under the *marketing* purpose, if they opt out of personalized marketing.

Some attributes are only allowed to be used under certain purposes.
For example, we allow the `sports_affinity` under the *editorial* purpose (given the user opts in to personalization for that purpose), while making in unavailable under the *ads* purpose.
This simplifies downstream logic for data consumers who previously might have had to resolve this out of band.

### Composed attributes

Some attributes are derived from multiple data sources.
For instance, a user changing their newspaper subscription plan is a rare occurrence, therefore, the `subscription_plan_batch` attribute is based on a table in our data lake, which is updated and ingested nightly.
However, we also receive events when this happens, which creates or updates the `subscription_plan_stream` attribute.

To streamline how the consumers use this data, they only see *virtual* user attributes, which are functions of the *physical* attributes we have talked about up until now.
A virtual attribute (e.g., `subscription_plan`) has an ordered list of physical attributes (e.g., `[subscription_plan_stream, subscription_plan_batch]`).
A virtual attribute's value resolves to one of the physical values depending on the chosen *selection strategy* for that virtual attribute:

<dl class="dl-inline">
<dt>Coalesce:</dt>
<dd>The first non-null value in the ordered list of physical attributes.</dd>

<dt>Newest:</dt>
<dd>The newest non-null value among the list of physical attributes. Order is ignored.</dd>

<dt>Special:</dt>
<dd>
Value selection or composition is hard-coded in the application, i.e., not configurable at
runtime.
</dd>
</dl>

Virtual attributes lets us present a clean and stable interface to consumers, even when underlying data sources change, vary in freshness, or in reliability.

### Easy-to-use management dashboard

Our flexible data model gives us the power to add attributes, modify their composition or type, associate them with purposes and consent data.
To make this easy, we have developed a management dashboard that streamlines common operations and gives us an overview of attributes and data freshness.

The management dashboard is a server-side rendered website with [htmx](https://htmx.org/) for dynamic content.

The dashboard has list pages for the physical and virtual attribute catalogs, purposes, and ingest jobs.
Each attribute entry has a detail page and an edit page.
Each purpose can also be edited, and each job has a detail page.
It's also possible to add new attributes via the dashboard.
Every developer in our organization can view all data, but only data platform developers can POST to the edit and new endpoints.

The management dashboard allows us to swiftly carry out necessary modifications and lets us get fast overviews of the data in our service.

<section class="carousel">
<h5 hidden>Management dashboard screenshots</h5>

<figure>
<a href="/manager-backend.png" target="_blank">
<img src="/manager-backend.png" alt="Screenshot of the physical (backend) attribute list page.">
</a>
<figcaption>
List of physical attributes.
For legacy reasons, we refer to physical attributes as <em>backend datapoints</em>, and
virtual attributes as <em>public datapoints</em>.
See <a href="#attribute-terminology">this aside</a>.
</figcaption>
</figure>

<figure>
<a href="/manager-backend-details.png" target="_blank">
<img src="/manager-backend-details.png" alt="Screenshot of the physical attribute details page.">
</a>
<figcaption>
The details page of a physical attribute.
</figcaption>
</figure>

<figure>
<a href="/manager-backend-edit.png" target="_blank">
<img src="/manager-backend-edit.png" alt="Screenshot of the physical attribute edit page.">
</a>
<figcaption>
The edit page of a physical attribute.
</figcaption>
</figure>

<figure>
<a href="/manager-public.png" target="_blank">
<img src="/manager-public.png" alt="Screenshot of the virtual (public) attribute list page.">
</a>
<figcaption>
List of virtual attributes.
</figcaption>
</figure>

<figure>
<a href="/manager-public-edit.png" target="_blank">
<img src="/manager-public-edit.png" alt="Screenshot of the virtual attribute edit page.">
</a>
<figcaption>
The edit page of a virtual attribute.
</figcaption>
</figure>

<figure>
<a href="/manager-jobs.png" target="_blank">
<img src="/manager-jobs.png" alt="Screenshot of the batch ingest job list page.">
</a>
<figcaption>
List of batch ingest jobs.
</figcaption>
</figure>
</section>

<aside id="attribute-terminology">
<h5>Attribute terminology</h5>
<p>
In this article, I have presented <em>physical and virtual attributes</em>.
In Inquire, we use the terminology <em>backend and public datapoints</em>.
The <em>datapoints</em> terminology was somewhat inherited from the legacy systems.
The physical and virtual attribute terminology better match my current understanding of the
data model.
</p>
</aside>

### Type checking of attribute values

The [EAV data model](#flexible-data-modeling-with-eav) stores attribute values as JSON in the database.
This is great for flexibility, but sacrifices type safety at rest.
To simplify the batch ingestor pipeline, we do not have any type checking of the data imported from our data lake.
(The data in our data lake is, however, typed.)
Instead, we type check the JSON data on every query from consumers, and log fatal errors if a discrepancy from the expected type (as stored in the attribute catalog) should be found.

To date, after nearly one year of operation with approximately 250 requests per second on average over 30 attributes, we have not had a single instance of wrong typing.
This has given us confidence in that the tradeoff for flexibility against rigidness has been worthwhile.

### High-resolution metrics

We have metrics recording the use of each virtual attribute per consumer per purpose.
Additionally, we record whether a request for an attribute returned a null value or actual data.
This allows us to answer questions like these:

- Which attributes are currently in use by any consumer?
- Which consumers use a certain attribute?
- For what purpose does a certain consumer use data?
- What attribute does a certain consumer use?
- An attribute's hit rate suddenly dropped to 0%, why?

These metrics have been invaluable.
We can now confidently deprecate attributes, catch stale data early, and prove compliance when needed.

### Performance considerations

The [EAV data model](#flexible-data-modeling-with-eav) places multiple rows per user in our data table.
This bars us from using a single ID (e.g., user ID) as lookup value when fetching data for a user.
Instead, we have to fetch rows corresponding for all relevant attributes for that user.
We also make the observation that multiple requests for the same user (but for different attributes) is likely to occur within a short span of time, since multiple backends querying Inquire are involved for every page load.

To make the EAV model viable at scale, I indexed user ID to speed up multi-row lookups.

To avoid hitting the database for each request for the same user in the same page load, we added an in-memory cache to the API application.
When *any* user data is requested, we fetch *all* attribute values for that user and store them in the cache for a couple of seconds.
Subsequent requests for that user use in-memory attribute values.
We have approximately 30% cache hit rate.
This is quite low, but is explained by us having multiple replicas, so subsequent requests might hit a different process.
Each cache hit saves a database round-trip.

## Impact

Inquire is the central analytics user data API for personalization across Amedia's product ecosystem, serving hundreds of millions of requests monthly.
By addressing flexibility, governance, and observability, it has empowered product and marketing teams to iterate faster.

My role in leading the design and implementation of the system's architecture, data modeling, and APIs has given me valuable experience in building scalable, developer-friendly platforms.
