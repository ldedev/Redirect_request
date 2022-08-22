module main

import vweb
import time
import rand
import term
import net.urllib
import ldedev.ini
import encoding.base64

struct DataRequest {
pub mut:
	url         string
	body        string
	method      string = 'GET'
	id          string
	id_context  string
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
	access_ini := ini.read_ini('./access.ini') or { panic('access.ini not found') }

	port := match 'conf' in access_ini {
		'port' in access_ini['conf'] {
			access_ini['conf']['port'].int()
		}
		else {
			panic('[conf]-> port not found in access.ini')
			0
		}
	}

	go job_status_request()
	term.clear()
	vweb.run(&Ws{}, port)
}

['/:id_context'; get; post]
fn (mut ws Ws) redirect_me_access(id_context string) vweb.Result {
	mut url_param := urllib.query_unescape(ws.req.url.after('?')) or { ws.req.url.after('?') }

	id := rand.uuid_v4()
	url_param = match true {
		url_param.starts_with(':') {
			url_param[1..] or { '' }
		}
		url_param.starts_with('/:') {
			value := url_param[2..] or { '/' }
			'$value'
		}
		else {
			url_param
		}
	}
	unsafe {
		data_stack.stack[id_context][id] = DataRequest{
			id: id
			id_context: id_context
			url: if url_param.starts_with('//') { url_param[1..] } else { url_param }
			body: base64.encode(ws.req.data.bytes())
			method: ws.req.method.str()
			concluded: false
			waitingtime: time.now().add(10 * time.minute)
		}
	}
	for {
		if id !in data_stack.stack[id_context] {
			return ws.json({
				'status': {
					'msg':  'timeout'
					'code': '408'
				}
			})
		}

		if data_stack.stack[id_context][id].concluded
			&& data_stack.stack[id_context][id].response.data_received {
			break
		}

		time.sleep(time.millisecond * rand.int_in_range(50, 150) or { 100 })
	}

	defer {
		unsafe {
			data_stack.stack[id_context].delete(id)
		}
	}

	return ws.ok(data_stack.stack[id_context][id].response.body)
}

['/put_data/:id_context/:id'; post]
fn (mut ws Ws) put_data(id_context string, id string) vweb.Result {
	if id_context in data_stack.stack {
		if id in data_stack.stack[id_context] {
			body := ws.req.data
			unsafe {
				data_stack.stack[id_context][id].response.body = base64.decode_str(body)
				data_stack.stack[id_context][id].response.data_received = true
				data_stack.stack[id_context][id].concluded = true
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

// temporário!
fn (mut ws Ws) list_stack() vweb.Result {
	return ws.json(data_stack.stack)
}

['/get_context_request/:id_context']
fn (mut ws Ws) get_context_request(id_context string) vweb.Result {
	if id_context !in data_stack.stack {
		return ws.json({
			'status': {
				'msg':  'empty stack'
				'code': '404'
			}
		})
	}

	if data_stack.stack[id_context].len == 0 {
		return ws.json({
			'status': {
				'msg':  'empty stack'
				'code': '404'
			}
		})
	}

	mut id := ''

	for i in data_stack.stack[id_context].keys() {
		if !data_stack.stack[id_context][i].worker {
			id = i
			break
		} else if data_stack.stack[id_context][i].worker
			&& time.now() >= data_stack.stack[id_context][i].work_time {
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
		data_stack.stack[id_context][id].worker = true
		data_stack.stack[id_context][id].work_time = time.now().add(time.minute * 3)
	}
	if id == '' {
		return ws.json({
			'status': {
				'msg':  'empty stack'
				'code': '404'
			}
		})
	}

	return ws.json(data_stack.stack[id_context][id])
}

fn job_status_request() {
	for {
		for key_id_context, _ in data_stack.stack {
			for key, _ in data_stack.stack[key_id_context] {
				time_now := time.now()
				if time_now > data_stack.stack[key_id_context][key].waitingtime {
					unsafe {
						data_stack.stack[key_id_context][key].waitingtime = time.now().add(3 * time.minute)
						data_stack.stack[key_id_context][key].concluded = true
					}
				}

				if data_stack.stack[key_id_context][key].concluded
					&& time_now > data_stack.stack[key_id_context][key].waitingtime {
					unsafe {
						data_stack.stack[key_id_context].delete(key)
					}
				}
			}
		}

		time.sleep(30 * time.second)
	}
}
