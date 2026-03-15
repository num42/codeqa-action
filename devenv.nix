{pkgs, ...}: {
  packages = [
    pkgs.beam.packages.erlang_27.elixir_1_19
  ];

  languages.elixir = {
    enable = true;
    package = pkgs.beam.packages.erlang_27.elixir_1_19;
  };

  enterShell = ''
    elixir --version
    mix deps.get
  '';
}
