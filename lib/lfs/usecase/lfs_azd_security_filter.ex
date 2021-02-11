defmodule Lfs.Usecase.AzdSecurityFilter do
  alias Lfs.Utils.RestClient
  alias Lfs.Utils.DataTypeUtils

  def validateReadRepo(repoName, authData) do

    #{:ok, _code, _h, body} = Lfs.Utils.RestClient.doGet(reposUrl, headers)
    #Enum.filter(DataTypeUtils.normalize(body["value"]), fn  e -> String.downcase(e.name) ==  String.downcase("AW000000_DEMO_AUDITORIA")  end )
    :error
  end
end
