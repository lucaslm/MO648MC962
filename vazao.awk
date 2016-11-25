# Matches lines which contains a receiver's ids, and store it on an array
$0 ~ /^node_r_[0-9]+ -> [0-9]+$/{
    receivers[$3]=$1
}

# Searches all the lines for ns event traces,
# to sum all data relayed to any receiver
{
    if ($1=="r" && ($5=="DCCP_Data" || $5=="DCCP_DataAck") && $4 in receivers){
        soma = soma + $6
    }
}

END{
    vazao = (soma/10)
    vazao = vazao/1024/1024*8
    print soma, vazao
}
