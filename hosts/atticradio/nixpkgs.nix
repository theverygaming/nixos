{ flakeInputs, ... }:

import flakeInputs.nixpkgs {
  system = "x86_64-linux";
}
