#!/bin/bash

default_api="https://api1.eosasia.one"
default_config="./config.ini"
api=${default_api}
config=${default_config}

UNAME=`uname`

if [[ $UNAME == 'Darwin' ]]; then
  checker='shasum -a 256'
else
  checker='sha256sum'
fi

init() {
    [ "$1" != "" ] && api=$1
    [ "$2" != "" ] && config=$2
    [ ! -f ${config} ] && echo "please check config path(${config})" && exit 1
}

get_chain_actor_list() {
    url="${api}/v1/chain/get_table_rows"
    chain_actor_list=`curl -s ${url} -X POST -d '{"scope":"theblacklist", "code":"theblacklist", "table":"theblacklist", "json": true, "limit": 100 \
 }' | python  -c "import sys, json; rows = json.load(sys.stdin)['rows'];result = ''; configs = []; [configs.extend([('# %s = %s' % (r['type'], a) if r['action'] != 'add' else '%s = %s' % (r['type'], a)) for a in r['accounts']])for r in rows]; dups = [configs[j] for i in range(len(configs)) for j in range(i+1, len(configs)) if('# ' + configs[i] == configs[j])]; actors=[]; l = [(a if (r['action'] != 'remove' and '# %s = %s' % (r['type'], a) not in dups) else '' for a in r['accounts']) for r in rows]; [actors.extend(list(l)) for l in l]; actors = list(set([a for a in actors if len(a)])); actors.sort(); print '\n'.join(actors)"`
}

get_local_actor_list() {
    local_actor_list=`cat ${config} | grep actor-black | grep -v "#" |egrep -o '\w+$'| sort | uniq`
}

check_diff() {
    diff <(echo "${chain_actor_list}") <(echo "${local_actor_list}")| sed 's/</chain -/g' | sed 's/>/local -/g' | egrep 'chain -|local -'
}

# check local and theblacklist actor-blacklist hash
check_hash() {
    local_hash=`cat ${config} | grep actor-black | grep -v "#" | sort | uniq | tr -d " " | ${checker}`
    # get hash from table theblacklist
    chain_hash=`echo "${chain_actor_list}" | sed 's/^/actor-blacklist = /g' | tr -d " " | ${checker}`
    if [ "${local_hash}" == "${chain_hash}" ];then
        echo "success: ${chain_hash}"
    else
        echo "local: ${local_hash}"
        echo "chain: ${chain_hash}"
    fi
}

main() {
    init $@
    get_chain_actor_list
    get_local_actor_list
    check_diff
    check_hash
}

main $@
