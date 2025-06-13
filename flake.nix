{
  description = "DuckDuckGo MCP Server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      uv2nix,
      pyproject-nix,
      pyproject-build-systems,
    }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          overlay = workspace.mkPyprojectOverlay {
            sourcePreference = "wheel";
          };
          pyprojectOverlay = pyproject-nix.overlays.default;
          python = pkgs.python312;
          pythonSet =
            (pkgs.callPackage pyproject-nix.build.packages {
              inherit python;
            }).overrideScope
              overlay;
        in
        {
          default = pythonSet.mkVirtualEnv "duckduckgo-mcp-server-env" workspace.deps.default;
          duckduckgo-mcp-server = pythonSet.buildPythonPackage (workspace.mkPyprojectArgs ./.);
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          overlay = workspace.mkPyprojectOverlay {
            sourcePreference = "wheel";
          };
          pyprojectOverlay = pyproject-nix.overlays.default;
          python = pkgs.python312;
          pythonSet =
            (pkgs.callPackage pyproject-nix.build.packages {
              inherit python;
            }).overrideScope
              overlay;
        in
        {
          # Impure shell using uv
          impure = pkgs.mkShell {
            packages = [
              pkgs.uv
              python
            ];
            shellHook = ''
              export UV_PYTHON_DOWNLOADS=never
              export UV_PYTHON="${python}/bin/python"
            '';
          };

          # Pure shell with editable package
          default = pythonSet.mkVirtualEnv "duckduckgo-mcp-server-dev" (
            workspace.deps.default
            ++ [
              (pythonSet.mkEditablePackage (workspace.mkPyprojectArgs ./.))
            ]
          );
        }
      );
    };
}
