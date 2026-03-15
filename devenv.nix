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

  scripts.precommit.exec = ''
    mix precommit
  '';

  git-hooks.hooks.mix-precommit = {
    enable = true;
    name = "Mix precommit";
    entry = "devenv shell precommit";
    language = "system";
    pass_filenames = false;
  };
}
