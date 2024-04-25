<h1>Instruções para Executar a Simulação</h1>

Este guia fornece instruções simples para executar a simulação do projeto.

**Passos:**

1. **Navegue até o Diretório da Simulação:**

Abra um terminal e vá para o diretório da simulação utilizando o comando cd. Por exemplo:
~~~bash
cd sim
~~~
2. **Compilação:**

Utilize o script compile.tcl para compilar a simulação. Execute o seguinte comando:
~~~bash
tclsh compile.tcl
~~~
3. **Visualização da Simulação:**
   
Após a compilação, será gerado um arquivo chamado MIPS_monocycle_tb.ghw. Abra este arquivo utilizando o GTKWave para visualizar os resultados da simulação.

<h3>Observações:</h3>

* Certifique-se de ter o GTKWave instalado para visualizar os resultados da simulação e o GHDL para compilação do código.

* **Warnings durante a compilação são ignorados.**
