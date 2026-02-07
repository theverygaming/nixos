{ ... }:

{
  users.users."root" = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGGEXP+YFeEihXZGZjtvbthkNayMOXwMLLtugMS7YAdS"
    ]; # TODO: ssh key from https://github.com/theverygaming.keys?
  };
}
