{
        if ($1=="r" && ($5=="DCCP_Data" || $5=="DCCP_DataAck") && ($4=="3")){
                #print $1
                soma = soma + $6
        }
}
END{
        vazao = (soma/10)
        vazao = vazao/1024/1024*8
        print soma, vazao
}
