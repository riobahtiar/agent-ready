# shellcheck shell=bash
# oh-my-pi (omp) — https://github.com/can1357/oh-my-pi
# herdr's omp hook needs ~/.omp/agent/extensions, which omp creates on first
# launch: run omp once, then `agents herdr`.
agent_define omp \
    env="ANTHROPIC_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY GEMINI_API_KEY" \
    title="oh-my-pi (omp)" \
    wrapper=b-omp \
    herdr=omp \
    login="omp   then type /login" \
    paths="~/.bun/bin/omp ~/.local/bin/omp" \
    config="~/.omp"

omp_install() { _vendor_script https://omp.sh/install sh; }
