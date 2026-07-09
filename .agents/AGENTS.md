
- **Data Rigor**: NEVER use synthetic data, random noise (e.g., randn), or proxy 'fake' points for visualizations, model demonstrations, or analysis without obtaining explicit upfront user permission. Always extract and compute on true data subsets.

- **Questions vs Actions**: When the user asks a question that requires an answer or discussion (e.g., "How can I do X?"), ONLY answer the question. Do NOT assume permission to automatically execute commands or apply the solution without explicit approval.

- **Git Workflow**: When instructed to save changes to git, ONLY commit the code (`git commit`). NEVER push to a remote repository (`git push`) unless explicitly and specifically requested to do so for that specific invocation.
