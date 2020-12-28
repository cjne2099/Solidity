/*******************************************************************
 Contrato Inteligente para garantir pagamento de aluguel.
*******************************************************************/

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.7.0;

contract ContratoDeAluguel {

    uint valor;                     // Valor do aluguel sem encargos
    uint vencimento;                // Ciclo para para pagamento sem encargos
    address payable locador;        // Endereço da conta do Locador
    address locatario;              // Endereço da conta do Locatário
    address payable seguro;         // Endereço da conta do Seguro Fiança
    address payable contrato;       // Endereço do contrato inteligente de aluguel
    uint multa;                     // Valor da multa
    uint inicio;                    // Unix timestamp do momento de início do contrato (deploy)
    uint prazo;                     // Prazo em meses do contrato
    uint contador;                  // Contador de inadimplencia
    uint i;                         // Contagem mensal do tempo
    mapping (uint=>uint) meses;     // Mapear data do pagamento para a Competencia
    
    constructor(uint valorDoAluguel, uint dataVencimento, uint valorDaMulta, uint prazoEmMeses, address contaLocatario, address payable contaSeguroFianca) {
        valor = valorDoAluguel;
	prazo = prazoEmMeses;
        locatario = contaLocatario;
        seguro = contaSeguroFianca;
        multa = valorDaMulta;
        vencimento = dataVencimento;
        locador = msg.sender;
        inicio = block.timestamp; 
    }
    
    function incrementarcontador () private {
        contador = 1;
        i = 1;
        while (block.timestamp < inicio + prazo * 30 days) {
            if (block.timestamp == inicio + i*vencimento*1 days) {
                contador = contador++;
                i = i++;
            }
        }
    }

    function carregarseguro () payable public { // Carregar valor do seguro no contrato
        require(msg.sender == seguro, "Somente Seguro Fianca pode carregar seguro");
        require(msg.value == 3*valor, "Valor do seguro incorreto");
    }
    
    function pagaraluguel (uint mes) payable public {
        require (mes > 0 && mes <= prazo, "Competencia inexistente no contrato.");
        require (!mesestapago (mes), "Competencia paga");
        if ((block.timestamp - inicio *1 days) % vencimento > 0 && (block.timestamp - inicio *1 days) % vencimento < 1) {
            require(msg.value >= valor, "Valor de aluguel incorreto.");
            meses[mes] = block.timestamp;
            contador = contador--;
        }
        else {
            require(msg.value >= valor + multa, "Acrescentar valor da multa ao pagamento.");
            meses[mes] = block.timestamp;
            contador = contador--;
        }
    }
    
    function mesestapago(uint mes) view public returns(bool) { // verificar se a Competencia do mês está paga
        if(meses[mes] == 0) return false;
        else return true;
    }
    
    function liberarseguro () view private returns (bool) { // verificar se o seguro está liberado para o locador
        if (contador >= 3) return false;
        else return true;
    }
    
    function consultarsaldo () view public returns (uint256) { // consultar o saldo disponível para resgate (aluguel + seguro)
        require(msg.sender == locador, "Somente locador pode consultar o saldo.");
	return address(this).balance;
    }
    
    function resgatealuguel(uint _resgatealuguel) public { // resgatar o aluguel. Seguro só pode ser resgatado se estiver liberado
        require(msg.sender == locador, "Somente locador pode solicitar resgate.");
        require(_resgatealuguel <= address(this).balance, "Saldo do aluguel insuficiente para o resgate.");
        if (!liberarseguro()) locador.transfer(_resgatealuguel);
        else locador.transfer(_resgatealuguel - 3*valor);
    }
    
    function resgateseguro(uint resgateseg) public { // reinconporar o seguro ao gestor de recursos, caso não tenha sido utilizado
        require(msg.sender == seguro, "Somente Seguro Fianca pode solicitar resgate.");
        require(block.timestamp > inicio + prazo, "Resgate negado. Contrato vigente.");
        require(resgateseg == 3*valor, "Valor do Seguro incorreto.");
        require(liberarseguro(), "Seguro liberado para o locador.");
        seguro.transfer(resgateseg);
    }
    
}    
