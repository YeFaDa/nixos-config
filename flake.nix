{
  description = "My NixOS Flake Configuration";

  inputs = {
    # 这里决定了你使用 unstable 还是 25.11
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    #NUR仓库
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #noctalia v5
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # noctalia 官方登录界面（greetd greeter）
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # CachyOS 内核（bore/lto/zen4 等变体），pinned overlay 命中 attic 二进制缓存
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    #niri-glass
    niri-glass.url = "github:YeFaDa/Niri-glass";
    /* home-manager = {
      url = "git+https://gitcode.com/GitHub_Trending/ho/home-manager.git";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };*/
    # 引入插件仓库
    vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    # OMP（Oh My Pi）harness，agents/omp.nix 使用
    omp-nix.url = "github:yuxqiu/omp-nix";
    
    #flclash
    flclash-nix = {
      url = "github:YeFaDa/flclash-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    denial = {
      url = "github:YeFaDa/denial.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Astral Game（本地打包：预编译 bundle + TUN 提权 module）
    astral-game = {
      url = "git+file:///home/yz/astral-game.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, vscode-extensions, nur, ... }@inputs: {
    # 把 "your-hostname" 改成你在 configuration.nix 里定义的 networking.hostName
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
    #  system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        {
          nixpkgs.overlays = [ nur.overlays.default ];
        }
        ./configuration.nix # 引用你现有的配置
        ./noctalia.nix
        ./software-configuration.nix
        #./proxy/clash.nix
        ./vscode.nix
        ./games/game-prepare.nix
        ./kvm+qemu+virt/default.nix
        #./agents/deepseek-harness.nix
        ./agents/omp.nix
        ./proxy/flclash.nix
        ./pixi.nix
        ./denial.nix
        ./astral.nix
    /*home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            # 这里的 ryan 也得替换成你的用户名
            # 这里的 import 函数在前面 Nix 语法中介绍过了，不再赘述
            home-manager.users.yz = import ./home.nix;

            # 使用 home-manager.extraSpecialArgs 自定义传递给 ./home.nix 的参数
            # 取消注释下面这一行，就可以在 home.nix 中使用 flake 的所有 inputs 参数了
            home-manager.extraSpecialArgs = inputs;
          }*/
      ];
    };
  };
}
