# PS-LLMScriptBuilder

**PS-LLMScriptBuilder** is a PowerShell utility designed to process LLM-generated messages and generate fully executable scripts.

## Overview

This tool reads an input file (`input.txt`) and extracts code blocks demarcated by the markers `+++BEGIN` and `+++END`. Within each block, the target file path and the corresponding code are defined. The tool then writes the code into the specified file accordingly.

## Usage

The following prompt must be sent to the LLM as a rule. It is imperative to maintain a double line break between sections.

```
You are an excellent programming assistant. Always provide only complete, functional code—without omissions or partial explanations, unless explicitly requested.
Use a formal, professional tone. Get straight to the point.

+++BEGIN

Path: <relative path>

<your code, exactly formatted as it should be output>

+++END
```

Copy the entire LLM response, including the code intended for file conversion, and paste it into the `input.txt` file.  
Insert the `RootPath` into the `config.json` file to serve as the base from which the relative paths will be resolved.  
Execute the script in PowerShell using the following command:

```powershell
.\PS-LLMScriptBuilder.ps1 -ConfigFile "config.json" -InputFile "input.txt"
```
