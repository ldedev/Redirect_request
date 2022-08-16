module main

import vweb
import time
import rand
import net.urllib

struct DataRequest {
	url      string
	body     string
	method   string = 'GET'
	id       string
	cnpj_cpf string
pub mut:
	concluded   bool
	waitingtime time.Time
	response    DataResponse

	worker    bool
	work_time time.Time
}

struct DataResponse {
pub mut:
	data_received bool
	body          string
}

struct StackRequest {
pub mut:
	stack map[string]map[string]DataRequest
}

const data_stack = &StackRequest{}

struct Ws {
	vweb.Context
}

fn main() {
	go job_status_request()

	vweb.run(&Ws{}, 4060)
}

['/:cnpj'; get; post]
fn (mut ws Ws) redirect_me_access(cnpj_cpf string) vweb.Result {
	url_param := urllib.query_unescape(ws.req.url.after('?')) or { ws.req.url.after('?') }

	if cnpj_cpf.len == 14 || cnpj_cpf.len == 11 {
	} else if !cnpj_cpf.split('').all(it[0].is_digit()) {
		return ws.json({
			'status': {
				'msg':  'invalid cnpj/cpf'
				'code': '401'
			}
		})
	}

	id := rand.uuid_v4()
	unsafe {
		data_stack.stack[cnpj_cpf][id] = DataRequest{
			id: id
			cnpj_cpf: cnpj_cpf
			url: if url_param == ':' { '' } else { url_param }
			body: ws.req.data
			method: ws.req.method.str()
			concluded: false
			waitingtime: time.now().add(10 * time.minute)
		}
	}
	for {
		if id !in data_stack.stack[cnpj_cpf] {
			return ws.json({
				'status': {
					'msg':  'timeout'
					'code': '408'
				}
			})
		}

		if data_stack.stack[cnpj_cpf][id].concluded
			&& data_stack.stack[cnpj_cpf][id].response.data_received {
			break
		}

		time.sleep(time.millisecond * 700)
	}

	body := data_stack.stack[cnpj_cpf][id].response.body

	unsafe {
		data_stack.stack[cnpj_cpf].delete(id)
	}

	return ws.ok(body)
}

fn (mut ws Ws) list_stack() vweb.Result {
	return ws.json(data_stack.stack)
}

['/get_context_request/:cnpj_cpf']
fn (mut ws Ws) get_context_request(cnpj_cpf string) vweb.Result {
	if cnpj_cpf !in data_stack.stack {
		return ws.json({
			'status': {
				'msg':  'empty stack'
				'code': '404'
			}
		})
	}

	if data_stack.stack[cnpj_cpf].len == 0 {
		return ws.json({
			'status': {
				'msg':  'empty stack'
				'code': '404'
			}
		})
	}

	mut id := ''

	for i in data_stack.stack[cnpj_cpf].keys() {
		if !data_stack.stack[cnpj_cpf][i].worker {
			id = i
			break
		} else if data_stack.stack[cnpj_cpf][i].worker
			&& time.now() >= data_stack.stack[cnpj_cpf][i].work_time {
			id = i
			break
		}
	}

	if id == '' {
		return ws.json({
			'status': {
				'msg':  'empty stack'
				'code': '404'
			}
		})
	}

	unsafe {
		data_stack.stack[cnpj_cpf][id].worker = true
		data_stack.stack[cnpj_cpf][id].work_time = time.now().add(time.minute * 3)
	}
	if id == '' {
		return ws.json({
			'status': {
				'msg':  'empty stack'
				'code': '404'
			}
		})
	}

	return ws.json(data_stack.stack[cnpj_cpf][id])
}

['/put_data/:cnpj_cpf/:id'; post]
fn (mut ws Ws) put_data(cnpj_cpf string, id string) vweb.Result {
	if cnpj_cpf in data_stack.stack {
		if id in data_stack.stack[cnpj_cpf] {
			body := ws.req.data
			unsafe {
				data_stack.stack[cnpj_cpf][id].response.body = body
				data_stack.stack[cnpj_cpf][id].response.data_received = true
				data_stack.stack[cnpj_cpf][id].concluded = true
			}
			return ws.json({
				'status': {
					'msg':  'ok'
					'code': '200'
				}
			})
		}
	}

	return ws.json({
		'status': {
			'msg':  'ok'
			'code': '200'
		}
	})
}

fn job_status_request() {
	for {
		for key_cnpj_cpf, _ in data_stack.stack {
			for key, _ in data_stack.stack[key_cnpj_cpf] {
				time_now := time.now()
				if time_now > data_stack.stack[key_cnpj_cpf][key].waitingtime {
					unsafe {
						data_stack.stack[key_cnpj_cpf][key].waitingtime = time.now().add(3 * time.minute)
						data_stack.stack[key_cnpj_cpf][key].concluded = true
					}
				}

				if data_stack.stack[key_cnpj_cpf][key].concluded
					&& time_now > data_stack.stack[key_cnpj_cpf][key].waitingtime {
					unsafe {
						data_stack.stack[key_cnpj_cpf].delete(key)
					}
				}
			}
		}

		time.sleep(30 * time.second)
	}
}
