add-content -path C:/Users/AJCla/.ssh/config -value @'

host ${hostname}
    Hostname %{hostname}
    User %{user}
'@