import {randomUUID} from "node:crypto";
import {DataManager} from "./data";
import {ServerManager} from "./server";


const dataManager = new DataManager({
    host: String(Bun.env.DB_HOST),
    port: Number(Bun.env.DB_PORT),
    user: String(Bun.env.DB_USER),
    password: String(Bun.env.DB_PASSWORD)
});

await dataManager.init();

const serverManager = new ServerManager({
    hostname: String(Bun.env.HOST),
    port: Number(Bun.env.PORT)
});

const clientServer = new Map<string, number>()

serverManager.onopen = (socket) => {
    let id: string;

    do {
        id = randomUUID();

    } while (clientServer.has(id))

    socket.data = {clientId: id};
}

serverManager.ondata = async (socket, data) => {
    const clientId = socket.data.clientId;
    const buffer = socket.data.buffer ? Buffer.concat([socket.data.buffer, data]) : data;

    if (buffer.at(buffer.length - 1) !== 10) {
        socket.data = {clientId, buffer};
        return;
    }

    socket.data = {clientId, buffer: null};

    const messages = buffer.toString().split('\n').filter(Boolean);

    for (const message of messages) {
        let json;

        try {
            json = JSON.parse(message);
        } catch(e) {
            console.error(message);
            console.error(e);
            socket.end();
            return;
        }

        if (json.type === 'auth') {
            const serverId = await dataManager.checkAuthData(json.name);

            if (!serverId) {
                socket.end();
                return;
            }

            console.log(json.name, 'connected');

            clientServer.set(clientId, serverId);

        } else if (json.type === 'add') {

            const res = await dataManager.sendAddData({
                container_id: clientServer.get(socket.data.clientId)!,
                items: json.data.map((item: any) => ({
                    time: item.time.slice(0, -1),
                    log: item.log
                }))
            });

            if (!res) {
                socket.end();
            }
        } else {
            socket.end();
        }
    }
}

serverManager.run();
