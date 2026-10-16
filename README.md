<p align="center"><img src="Banner.svg" alt="Frostzn Dex — Explorer, propriedades e editor" width="100%"></p>

<p align="center"><strong>Explorer de cliente com interface escura, janelas móveis e ferramentas de inspeção.</strong><br>Personalização por Frostzn · Base Dex por Moon / LorekeeperZinnia / Infinite Yield</p>

<p align="center"><a href="LICENSE">Licença MIT</a> · <a href="NOTICE.md">Créditos e limites</a> · <a href="https://github.com/hugopbruu-spec/Frostzn-Dex/issues">Relatar problema</a></p>

## Executar

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hugopbruu-spec/Frostzn-Dex/main/Loader.lua"))()
```

O carregador instala o script, os metadados e os ícones deste repositório na pasta `FrostznDex` do workspace do executor. Na primeira execução, precisa de acesso a `raw.githubusercontent.com`; nas seguintes, reutiliza arquivos compatíveis do cache. Reexecutar com o painel ativo reabre o Explorer.

**Requisitos:** ambiente de execução Luau no cliente que ofereça `game:HttpGet`, `loadstring`, `readfile`, `writefile` e `makefolder`. O comando não é um LocalScript comum para colocar no Studio. O comportamento varia conforme o ambiente; compatibilidade universal não foi verificada.

## Ferramentas

| Recurso | O que faz |
| --- | --- |
| Explorer | Hierarquia real dos objetos acessíveis no cliente, com ícones e menu de contexto. |
| Propriedades | Inspeção e edição local quando a propriedade permite. |
| Editor | Sintaxe, até 20 abas, rascunhos recuperáveis durante a sessão e exportação. |
| Pesquisa | Nome, classe, herança, caminho, frases entre aspas e exclusões. |
| Observação | Câmera em jogador/objeto, com saída visível e restauração. |
| Download | Botão direito → **Baixar item…** → revisar seleção → **Baixar**. |
| Configurações | Orçamento de processamento, contornos e restauração dos encaixes. |

### Atalhos e janelas

- **F4:** recolher/abrir janelas encaixadas à direita.
- **F7:** sair da observação; também existe um botão permanente enquanto observa.
- Arraste a barra de título para mover/desencaixar; use as bordas para redimensionar.
- **Configurações → Restaurar encaixes:** reorganiza Explorer e Propriedades.
- **Encerrar Frostzn Dex:** remove suas interfaces e desconecta seus eventos.

### Pesquisa

```text
candy
class:LocalScript
isa:BasePart
only:scripts
only:remotes
parent:Map
path:Workspace.Map
"nome com espaços" -excluir
class:Script, class:ModuleScript
```

Espaços combinam condições; vírgulas fora de aspas combinam alternativas. `class:` aceita correspondência parcial; `isa:` considera herança. A pesquisa é cancelável e usa debounce de 350 ms. Repita a consulta para atualizar resultados após mudanças na hierarquia.

### Exportação

Os arquivos ficam em **`FrostznDex/saved`**, dentro do workspace do seu executor.

- Objetos, pastas, modelos e interfaces: `.rbxmx`, com descendentes acessíveis.
- Scripts com `Source` legível: `.lua`.
- Modelos acompanham um `.report.json` com limitações, referências, atributos e tags.
- Limites por operação: 20 raízes, 12 mil instâncias por raiz e profundidade de 180.
- Nomes são normalizados e o arquivo é relido antes de informar sucesso.

Meshes, texturas e sons mantêm os IDs de referência. Dados binários internos, assets privados, conteúdo não replicado e propriedades protegidas podem ficar ausentes. Atributos e tags constam no relatório; não são reaplicados automaticamente pelo XML. Scripts exportados ficam desativados. Outros tipos de asset podem precisar de ajuste no Studio.

## Código e servidor

**O cliente não recebe conteúdo exclusivo de `ServerStorage` ou `ServerScriptService`.** Esses serviços podem aparecer na árvore sem os arquivos do servidor. Esta ferramenta não contorna essa fronteira nem recupera fontes ausentes.

O editor tenta ler `Source` antes de declarar indisponibilidade. Fontes legíveis permitem edição local; **Aplicar Source** não reinicia automaticamente o script nem salva mudanças no servidor ou na place original. Para editar o projeto completo, use o projeto original no Roblox Studio.

Decompilação de cliente é manual, depende de uma função já existente no ambiente e pode produzir código diferente do original. Nenhum decompilador externo é instalado. Fontes acima de 250 KB não são renderizadas para preservar a interface.

## Desempenho e verificação

Indexação incremental, processamento repartido por quadro, busca cancelável e exclusão da própria UI reduzem trabalho desnecessário. O custo continua dependendo da experiência e do executor; não há garantia de FPS ou de ausência de travamentos.

A versão 2.0 passou por **23 verificações em uma sessão de Roblox Player**, incluindo indexação, propriedades, pesquisa, rascunhos, câmera, ícones, exportação, encaixes e encerramento. Um modelo de teste exportado passou por **oito verificações independentes de leitura**, incluindo dimensões e referências. Isso não representa auditoria de todos os menus, todos os assets, todos os dispositivos ou de estabilidade indefinida.

## Arquivos

| Arquivo | Função |
| --- | --- |
| `Loader.lua` | Instalação e cache das dependências; ponto de entrada do comando. |
| `Frostzn_Dex.lua` | Runtime completo derivado da base Dex fornecida. |
| `API.compact.json` | Metadados de classes usados pelo Explorer e propriedades. |
| `RMD.prepared.json` | Metadados de reflexão e ícones de classes. |
| `LauncherAtlas.png` | Sete ícones do menu lateral. |
| `manifest.json` | Versão, tamanhos e SHA-256 dos arquivos distribuídos. |
| `LICENSE` / `NOTICE.md` | Licença original e atribuições. |

O carregador verifica tamanhos, estrutura JSON, assinatura PNG e compilação do runtime. Os hashes do manifesto são fornecidos para conferência externa; o carregador não faz verificação criptográfica. Para atualizar uma sessão aberta, encerre o painel e execute o comando novamente. Seus arquivos salvos e configurações não são apagados pelo instalador.

## Créditos

**Frostzn** — personalização visual e manutenção desta versão. **Moon / LorekeeperZinnia / Infinite Yield** — base Dex e modificações anteriores. A licença MIT e os avisos originais foram preservados.

Referências: [Dex](https://github.com/LorekeeperZinnia/Dex), [Roblox Client Tracker](https://github.com/MaximumADHD/Roblox-Client-Tracker), [replicação e controle de acesso](https://create.roblox.com/docs/scripting/security/access-control), [formato XML no projeto rbx-dom](https://github.com/rojo-rbx/rbx-dom/blob/master/docs/xml.md).
