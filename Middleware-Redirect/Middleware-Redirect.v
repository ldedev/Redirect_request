import time
import net.http
import ldedev.ini
import json
import domain.models
import encoding.base64
import term

fn main() {

	access_ini := ini.read_ini('./access.ini') or { panic('access.ini not found') }

	id_context := match true {
		'conf' !in access_ini {
			panic('conf not found in access.ini')
			''
		}
		'id_context' !in access_ini['conf'] {
			panic('id_context not found in access.ini')
			''
		}
		else {
			access_ini['conf']['id_context']
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

	term.clear()
	println("Middleware started! ($serv_redirect_ip:$serv_redirect_port/$id_context?) <- ● -> ($endp_redirect_ip:$endp_redirect_port)")

	for {
		resp := http.get('http://$serv_redirect_ip:$serv_redirect_port/get_context_request/$id_context') or {
			http.Response{}
		}


		mut js_context_req := json.decode(models.ContextRequest, resp.body) or {
			time.sleep(time.millisecond * 1000)
			continue
		}

		body := base64.decode_str(js_context_req.body)

		if js_context_req.status.code == '200' {
			mut resp_endpoint := http.Response{}

			if js_context_req.method == 'GET' {
				resp_endpoint = http.get('http://$endp_redirect_ip:$endp_redirect_port/$js_context_req.url') or {
					time.sleep(time.millisecond * 1000)
					continue
				}
			} else if js_context_req.method == 'POST' {
				resp_endpoint = http.post('http://$endp_redirect_ip:$endp_redirect_port/$js_context_req.url',
					body) or {
					time.sleep(time.millisecond * 1000)
					continue
				}
			}

			// dump(resp_endpoint)

			http.post('http://$serv_redirect_ip:$serv_redirect_port/put_data/$id_context/$js_context_req.id',
				base64.encode(resp_endpoint.body.bytes())) or { http.Response{} }
		}

		time.sleep(time.millisecond * 600)
	}
}

fn find_result_from_request(requeried string, url_param string, body string) {
}
