# Material Delivery Contract

Status: initial projection
Updated: 2026-10-16

The application framework supports the common two-branch Material delivery contract used by Editing Studio: a large Raw Material payload can use a provider-specific direct upload transport while structured Material Data is registered through a CNCF Operation.

The framework preserves the Material ID and Raw Material URN supplied by Flutter Core across retries. It centralizes authentication/session transport for the CNCF branch and must not turn provider-specific Drive IDs into semantic identity or authorization.

Applications do not implement a distributed transaction between raw upload and CNCF registration. Delivery status/retry is modeled as convergence of independently retryable branches.
