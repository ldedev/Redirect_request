import time
import net.http
import ldedev.ini
import json
import domain.models

fn main() {
	println("Middleware started!")

	access_ini := ini.read_ini('./access.ini') or { panic('access.ini not found') }

	cnpj_cpf := match true {
		'conf' !in access_ini {
			panic('conf not found in access.ini')
			''
		}
		'cnpj_cpf' !in access_ini['conf'] {
			panic('cnpj_cpf not found in access.ini')
			''
		}
		else {
			access_ini['conf']['cnpj_cpf']
		}
	}

	serv_redirect_ip := match 'server-redirect' in access_ini {
		'ip' in access_ini['server-redirect'] {
			access_ini['server-redirect']['ip']
		}
		else {
			panic('[server-redirect]-> ip not found in access.ini')
			''
		}
	}

	serv_redirect_port := match 'server-redirect' in access_ini {
		'port' in access_ini['server-redirect'] {
			access_ini['server-redirect']['port']
		}
		else {
			panic('[server-redirect]-> port not found in access.ini')
			''
		}
	}

	endp_redirect_ip := match 'endpoint-redirect' in access_ini {
		'ip' in access_ini['endpoint-redirect'] {
			access_ini['endpoint-redirect']['ip']
		}
		else {
			panic('[endpoint-redirect]-> ip not found in access.ini')
			''
		}
	}

	endp_redirect_port := match 'endpoint-redirect' in access_ini {
		'port' in access_ini['endpoint-redirect'] {
			access_ini['endpoint-redirect']['port']
		}
		else {
			panic('[endpoint-redirect]-> port not found in access.ini')
			''
		}
	}

	for {
		resp := http.get('http://$serv_redirect_ip:$serv_redirect_port/get_context_request/$cnpj_cpf') or {
			http.Response{}
		}

		js_context_req := json.decode(models.ContextRequest, resp.body) or {
			time.sleep(time.millisecond * 1536)
			continue
		}

		if js_context_req.status.code != '404' {
			dump(js_context_req)
			println("\n")

		}

		if js_context_req.status.code == '200' {
			mut resp_endpoint := http.Response{}

			if js_context_req.method == 'GET' {
				resp_endpoint = http.get('http://$endp_redirect_ip:$endp_redirect_port/$js_context_req.url') or {
					time.sleep(time.millisecond * 1536)
					continue
				}
			} else if js_context_req.method == 'POST' {
				resp_endpoint = http.post('http://$endp_redirect_ip:$endp_redirect_port/$js_context_req.url',
					js_context_req.body) or {
					time.sleep(time.millisecond * 1536)
					continue
				}
			}

			http.post('http://$serv_redirect_ip:$serv_redirect_port/put_data/$cnpj_cpf/$js_context_req.id',
				resp_endpoint.body) or { http.Response{} }
		}

		time.sleep(time.millisecond * 800)
	}
}

fn find_result_from_request(requeried string, url_param string, body string) {
}
