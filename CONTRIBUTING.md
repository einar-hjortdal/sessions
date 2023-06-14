# Contributing

Please follow these standards

## Git workflow

1. Fork the project and clone your fork to your development environment
2. Add the original repository as an additional git remote called "upstream"
3. Create a new branch
    - The branch called production is the branch that goes live
    - The branch called meester is the branch used for development
    - Feature (feat_) branches are branched off and then merged into meester once features are bug-free
    - Release (rele_) branches are branched off meester and then merged into production
    - Bug fix (bugf_) branches are branched off production and then merged into both production, release 
    and meester

4. Write your code, test it and make sure it works
5. Commit your changes
6. Pull the latest code from upstream into your branch 

    Make sure your changes do not conflict with the original repository.

7. Push changes to the remote "origin" (your repository)
8. Create a pull request
  - If the pull request addresses an issue, tag the related issue
