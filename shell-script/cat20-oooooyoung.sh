Crontab_file="/usr/bin/crontab"
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
Info="[${Green_font_prefix}Информация${Font_color_suffix}]"
Error="[${Red_font_prefix}Ошибка${Font_color_suffix}]"
Tip="[${Green_font_prefix}Уведомление${Font_color_suffix}]"

check_root() {
    [[ $EUID != 0 ]] && echo -e "${Error} Текущая учетная запись без ROOT-прав, Невозможно продолжить, Получите ROOT ${Green_background_prefix}sudo su${Font_color_suffix} Команда для получения ROOT-прав(после выполнения может быть предложено ввести пароль текущей учётной записи). " && exit 1
}

install_env_and_full_node() {
    check_root
    sudo apt update && sudo apt upgrade -y
    sudo apt install curl tar wget clang pkg-config libssl-dev jq build-essential git make docker.io -y
    VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')
    DESTINATION=/usr/local/bin/docker-compose
    sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
    sudo chmod 755 $DESTINATION

    sudo apt-get install npm -y
    sudo npm install n -g
    sudo n stable
    sudo npm i -g yarn

    git clone https://github.com/CATProtocol/cat-token-box
    cd cat-token-box
    sudo yarn install
    sudo yarn build

    MAX_CPUS=$(nproc)
    MAX_MEMORY=$(free -m | awk '/Mem:/ {print int($2*0.8)"M"}')

    cd ./packages/tracker/
    sudo chmod 777 docker/data
    sudo chmod 777 docker/pgdata
    sudo docker-compose up -d

    cd ../../
    sudo docker build -t tracker:latest .
    sudo docker run -d \
        --name tracker \
        --cpus="$MAX_CPUS" \
        --memory="$MAX_MEMORY" \
        --add-host="host.docker.internal:host-gateway" \
        -e DATABASE_HOST="host.docker.internal" \
        -e RPC_HOST="host.docker.internal" \
        -p 3000:3000 \
        tracker:latest
    echo '{
      "network": "fractal-mainnet",
      "tracker": "http://127.0.0.1:3000",
      "dataDir": ".",
      "maxFeeRate": 30,
      "rpc": {
          "url": "http://127.0.0.1:8332",
          "username": "bitcoin",
          "password": "opcatAwesome"
      }
    }' > ~/cat-token-box/packages/cli/config.json
}

create_wallet() {
  echo -e "\n"
  cd ~/cat-token-box/packages/cli
  sudo yarn cli wallet create
  echo -e "\n"
  sudo yarn cli wallet address
  echo -e "Пожалуйста, сохраните адрес кошелька и сид-фразу, созданную выше."
}

start_mint_cat() {
  # Prompt for token ID
  read -p "Введите ID токена: " tokenId

  # Prompt for gas (maxFeeRate)
  read -p "Установите газ для минта: " newMaxFeeRate
  sed -i "s/\"maxFeeRate\": [0-9]*/\"maxFeeRate\": $newMaxFeeRate/" ~/cat-token-box/packages/cli/config.json

  # Prompt for amount to mint
  read -p "Количество: " amount

  cd ~/cat-token-box/packages/cli

  # Update the mint command with tokenId and amount
  command="sudo yarn cli mint -i $tokenId $amount"

  # Run the minting loop
  while true; do
      $command

      if [ $? -ne 0 ]; then
          echo "Не удалось выполнить команду"
          exit 1
      fi

      sleep 1
  done
}

check_node_log() {
  docker logs -f --tail 100 tracker
}

check_wallet_balance() {
  cd ~/cat-token-box/packages/cli
  sudo yarn cli wallet balances
}

send_token() {
  read -p "Введите ID токена(не название): " tokenId
  read -p "Адрес получателя: " receiver
  read -p "Количество токенов: " amount
  cd ~/cat-token-box/packages/cli
  sudo yarn cli send -i $tokenId $receiver $amount
  if [ $? -eq 0 ]; then
      echo -e "${Info} Токены успешно отправлены"
  else
      echo -e "${Error} Не удалось отправить, проверьте информацию и попробуйте снова"
  fi
}


echo && echo -e " ${Red_font_prefix}dusk_network Установка в один клик${Font_color_suffix} by \033[1;35moooooyoung\033[0m
Этот скрипт полностью бесплатный и с открытым исходным кодом, создан пользователем Twitter. ${Green_font_prefix}@ouyoung11 Разработчик${Font_color_suffix}, 
Добро пожаловать!
 ———————————————————————
 ${Green_font_prefix} 1.Установка ${Font_color_suffix}
 ${Green_font_prefix} 2.Создать кошелёк ${Font_color_suffix}
 ${Green_font_prefix} 3.Проверить баланс ${Font_color_suffix}
 ${Green_font_prefix} 4.Минт токенов ${Font_color_suffix}
 ${Green_font_prefix} 5.Логи синхронизации ${Font_color_suffix}
 ${Green_font_prefix} 6.Перевод токенов ${Font_color_suffix}
 ———————————————————————" && echo
read -e -p " Следуйте инструкциям выше и введите номер:" num
case "$num" in
1)
    install_env_and_full_node
    ;;
2)
    create_wallet
    ;;
3)
    check_wallet_balance
    ;;
4)
    start_mint_cat
    ;;
5)
    check_node_log
    ;;
6)
    send_token
    ;;
*)
    echo
    echo -e " ${Error} Введите правильный номер"
    ;;
esac
