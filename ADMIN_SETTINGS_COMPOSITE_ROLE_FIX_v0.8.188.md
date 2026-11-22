# Admin Settings Access Fix — v0.8.188

- Fixed route authorization and sidebar visibility for composite management role labels such as `Managing Director / Hospital Admin`.
- Management access now recognizes role strings containing owner/admin or Managing Director, rather than requiring one exact role token.
- AppShell and Sidebar now apply consistent management-role recognition, preventing `/settings` from being hidden or redirected due to composite role names.
- No database migration required.
