{
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
		zig2nix.url = "github:Cloudef/zig2nix?rev=0b33963d673ba1feb78e20f345a8fb08aff13169";
	};

	outputs = { nixpkgs, zig2nix, ... }@inputs: let
		system = "x86_64-linux";
		pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };

		dev-packages = [
			zig2nix.packages.${system}.zig-master
			pkgs.imhex
			# pkgs.glfw
			# pkgs.pkg-config
			# pkgs.vulkan-headers
            # pkgs.vulkan-loader
			# pkgs.vulkan-validation-layers
		];
	in {
		devShells.${system}.default = pkgs.mkShell {
			packages = dev-packages;

			shellHook = ''
				echo "Have fun translating!"
			'';
		};
	};
}
