# Frequently Asked Questions

## Can I port my existing NixOS configuration over to finix?

While finix and NixOS configurations may share some similarities, you will most likely run into issues if you try to install finix using your existing NixOS configuration. It is recommended to thouroughly read this documentation and the [options search](https://finix-community.github.io/finix/options.html) to see what you will need to change before attempting an installation.

## How compatible are modules from NixOS and modules from finix?

There are some NixOS modules that have been successfully ported over to finix with no changes required, but this will not be the case for the majority of modules. If you would like to submit a request for a NixOS module to be ported, feel free to open an issue on our GitHub repository.

## How stable is finix?

Finix is currently in an experimental state, but it is fully capable as a daily driver for users who are able to keep up with breaking changes and adjust their configurations accordingly. There is no stable branch as of writing, and many users build and run finix from the main branch or their own forks.

## Can I use other init systems with finix?

Not at the moment. Adding support for other init systems is actively being discussed.

## Is x program / y service supported?

Please consult the [options search](https://finix-community.github.io/finix/options.html), and look for any modules prefixed with `programs` or `services`.

## Can I convert my preexisting NixOS installation over to finix?

If you decide to go down this route, our recommendation is to create a separate root partition for your finix installation. A few users in the community have tried converting their existing NixOS install on the same root partition with mixed results. If you are able to get it working, feel free to share your method and we will happily add it to our documentation once we verify it is stable.

## Can I use `home-manager`?

There is a home-manager implementation in [community-modules](https://github.com/finix-community/community-modules), but most finix users run [Hjem](https://github.com/feel-co/hjem), a lighter alternative to home-manager with experimental first party support for finix.

## Is there an iso available?

There is an experimental [graphical installer](https://github.com/finix-community/installer) available, but the current recommended way to install finix is with existing NixOS disk images. See the [installation guide](./installation.md) for more details.
