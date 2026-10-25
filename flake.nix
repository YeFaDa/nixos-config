{
  description = "My NixOS Flake Configuration";

  inputs = {
    # 这里决定了你使用 unstable 还是 25.11
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # NUR 仓库（qoder-cn / zcode 的来源）。以 overlay 方式引入（接线在
    # software-configuration.nix 的 nixpkgs.overlays），包表达式由系统
    # nixpkgs 评估——nix profile 时代 qoder-cn 用的是 NUR flake.lock 自己
    # 钉的 nixpkgs（glibc 2.42），正是 MESA-LOADER 报错的来源之一。
    # 钉的是 nix profile 时代的同款 rev（当前沙箱解析不了 github API 的 HEAD）。
    # 日常更新：nix flake update nur / codex-desktop-linux / llm-agents / omp-nix
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # workbuddy（CodeBuddy 桌面版，官方 deb 重打包，源在 ~/workbuddy-nix）。
    # path: 引入 = 取工作树状态（package.nix 有未提交改动，即当前想要的状态）；
    # follows 保证用系统 nixpkgs 构建，不再自带一枚旧 glibc。
    workbuddy-nix = {
      url = "path:/home/yz/workbuddy-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # codex-desktop-linux
    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # llm-agents.nix（opencode2 的来源）
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
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
    #niri-glass
    niri-glass = {
      url = "github:YeFaDa/Niri-glass";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    /* home-manager = {
      url = "git+https://gitcode.com/GitHub_Trending/ho/home-manager.git";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };*/
    # 引入插件仓库
    vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # OMP（Oh My Pi）harness。自 nix profile 迁入后改由系统 nixpkgs 构建
    omp-nix = {
      url = "github:yuxqiu/omp-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Kimi Code CLI（MoonshotAI）。上游 flake 自带 pnpm 依赖与 SEA 打包，
    # follows 后由系统 nixpkgs（nodejs_24 24.21.0 ≥ 上游要求 24.15.0）构建。
    kimi-code = {
      url = "github:MoonshotAI/kimi-code";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    /*astral-game = {
      url = "git+file:///home/yz/astral-game.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };*/
  };

  outputs = { self, nixpkgs, vscode-extensions, ... }@inputs: {
    # 把 "your-hostname" 改成你在 configuration.nix 里定义的 networking.hostName
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
    #  system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix # 引用你现有的配置
        ./noctalia.nix
        ./software-configuration.nix
        #./honor-mta.nix # 荣耀分享/互传联盟(MTA)：bluetoothd -E + P2P 防火墙端口
        #./proxy/clash.nix
        ./vscode.nix
        ./games/game-prepare.nix
        ./kvm+qemu+virt/default.nix
        #./agents/deepseek-harness.nix
        #./agents/omp.nix
        ./proxy/flclash.nix
        ./pixi.nix
        #./denial.nix
        #./astral.nix
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
