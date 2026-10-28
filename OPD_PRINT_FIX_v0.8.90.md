# OPD print fix v0.8.90

Pre-printed letterhead mode: add a dedicated white 3-inch spacer and explicitly remove all header backgrounds, gradients, pseudo-elements, borders, and shadows from the generated header region in print media. Plain A4 mode is not targeted by this override.

No Supabase migration required. Browser PDF rendering and full production build still need to be tested in the deployment environment.
