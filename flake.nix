{
  description = "My NixOS Flake Configuration";

  inputs = {
    # 这里决定了你使用 unstable 还是 25.11
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "git+https://gitcode.com/GitHub_Trending/ho/home-manager.git";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # 引入插件仓库
    vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs = { self, nixpkgs, home-manager, vscode-extensions, ... }@inputs: {
    # 把 "your-hostname" 改成你在 configuration.nix 里定义的 networking.hostName
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
    #  system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix # 引用你现有的配置
	./noctalia.nix
	./software-configuration.nix
  ./proxy/clash.nix
	home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            # 这里的 ryan 也得替换成你的用户名
            # 这里的 import 函数在前面 Nix 语法中介绍过了，不再赘述
            home-manager.users.yz = import ./home.nix;

            # 使用 home-manager.extraSpecialArgs 自定义传递给 ./home.nix 的参数
            # 取消注释下面这一行，就可以在 home.nix 中使用 flake 的所有 inputs 参数了
            home-manager.extraSpecialArgs = inputs;
          }
      ];
    };
  };
}

