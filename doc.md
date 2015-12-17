# Introducing the Tendermint Socket Protocol (TMSP)

Contents:

- Motivation
- TMSP Overview
- Dummy TMSP Example (in Go)
- Another TMSP Example (in Go, Python, Javascript)
- Running Tendermint 
- Deploy a Tendermint Testnet

# Motivation

After many months of fussing around with blockchain design, 
it became increasingly apparent that a restructuring was in order which would 
provide a greater separation of concerns.

In particular, there are quite clearly two elements of a blockchain: 
the consensus engine (a network protocol facilitating an eventual strict ordering on transactions)
and the application state (account balances, storage, unspent outputs, contracts, etc.).
In fact, these two elements are present in many (all?!) popular internet services today.

What is unique about blockchains, as pioneered by Bitcoin,
in comparison to any other internet application sitting above a consensus engine, 
is the way in which the application state directly incentivizes the consensus, 
through inflation and fees, and the alleged possibilities for economic decentralization therein.

Bitcoin's success, however, be it as it may dependent on economic decentralization,
has marshalled a growing appreciation in finance and industry for 
its other characteristic features: transparency, accountability, and identity via strong cryptography. 

No doubt, those features are further supported, even nurtured, by economic decentralization, 
but they are present too without it, 
motivated and nurtured by the inherent decentralized aspects of the culture of open source itself, 
which is, some may sometimes forget, orders of magnitude bigger than Bitcoin, and growing rapidly.

Hence we have been inspired to take the defining feature of a blockchain -
direct incentivation of the consensus by the application state - and remove it completely,
in order to achieve a separation of concerns between the consensus and the application that 
will give us tremendous flexibility.

Of course, we intend over time to bring back the incentivization layer, 
but to do it in a manner which is motivated more directly by the needs and use cases of the technology's users.

In the meantime, we have an open source platform which can support up to 10,000 transactions per second, 
which is Byzantine Fault Tolerant, which uses state-of-the-art digital signatures,
which has a robust and secure networking layer, 
and which can run applications written in arbitrary programming languages.

Ladies and gentlement (and everyone inbetween), we are pleased to introduce, 
the new Tendermint, and her accomplice, the TMSP.

# TMSP Overview

The Tendermint Socket Protocol (TMSP) is an asyncronous message passing protocol
enabing a consensus engine, running in one process,
to manage an application state, running in another.

If you are of sound mind, the consensus engine will be Tendermint, 
and regardless of your soundness of mind, your application can be written in any programming language.

The only requirements we have are that applications be deterministic and implement the TMSP API.

The API is quite simple, as it boils down to the most basic interface between a consensus engine and its application state: `append_tx`, `get_hash`, `commit`, `rollback`.

That is, the consensus engine will receive new txs in the mempool, 
and run them through the application using `append_tx`.

After a few transactions, the consensus engine can ask for the state hash with `get_hash`.
This way, the only thing consensus has to know about the application is the state root hash,
which goes in the block header, so applications can support light client proofs easily.

When a block is committed, the consensus sends a `commit` message, indicating the application should save its latest state.

Converesely, a `rollback` message tells the application to go back to the latest committed state.

# First Example

Ok, let's do an example.

Make sure you [have Go installed](https://golang.org/doc/install) and put `$GOPATH/bin` on your `$PATH`.

Install the tmsp tool and example applications:

```
go get github.com/tendermint/tmsp/cmd/...
```

Now run `tmsp --help` to see the list of commands:

```
COMMANDS:
   batch	Run a batch of tmsp commands against an application
   console	Start an interactive tmsp console for multiple commands
   echo		Have the application echo a message
   info		Get some info about the application
   set_option	Set an option on the application
   append_tx	Append a new tx to application
   get_hash	Get application Merkle root hash
   commit	Commit the application state
   rollback	Roll back the application state to the latest commit
   help, h	Shows a list of commands or help for one command
   
GLOBAL OPTIONS:
   --address "tcp://127.0.0.1:46658"	address of application socket
   --help, -h				show help
   --version, -v			print the version
```

The `tmsp` tool lets us send tmsp messages to our application, to help build and debug them.

As you can see, the TMSP API has more than the four messages outlined above 
for convenience, configuration, and information purposes, but it remains quite general.

Let's start a dummy application:

```
dummy
```

In another terminal, run 

```
tmsp echo hello
tmsp info
```

A TMSP application must provide two things:

	- a socket server
	- a handler for TMSP messages

When we run the `tmsp` tool we open a new connection to the application's socket server, 
send the given tmsp message, and wait for a response.

The server may be generic for a particular language, and we provide one for golang in `tmsp/server`.
There is one for Python in `example/python/tmsp/server.py`, but it could use more love.

The handler is specific to the application, and may be arbitrary, 
so long as it is deterministic and conforms to the TMSP interface specification.

For example, starting the `dummy` application in golang looks like:

```
server.StartListener("tcp://0.0.0.0:46658", example.NewDummyApplication())
```

Where `example.NewDummyApplication()` has methods for each of the TMSP messages and `server` handles everything else.

See the dummy app in `example/golang/dummy.go`. It simply adds transaction bytes to a merkle tree, hashing when we call `get_hash` and saving when we call `commit`.

So when we run `tmsp info`, we open a new connection to the tmsp server, which calls the `Info()` method on the application, which tells us the number of transactions in our merlke tree.

Now, since every command opens a new connection, we provide the `tmsp console` and `tmsp batch` commands, 
to allow multiple TMSP messages on a single connection.

Running `tmsp console` should drop you in an interactive console for speaking TMSP messages to your application.

Try running these commands:

```
> echo hello
> info
> get_hash
> append_tx abc
> info
> get_hash
```

Similarly, you could put the commands in a file and run `tmsp batch < myfile`.

# Another Example

Now that we've got the hang of it, let's try another application, the "counter" app.

This application has two modes: `serial=off` and `serial=on`.

When `serial=on`, transactions must be a big-endian encoded incrementing integer, starting at 0.

We can toggle the value of `serial` using the `set_option` TMSP message.

Let's kill the console and the dummy application, and start the counter app:

```
counter
```

Again, the code is just 

```
server.StartListener("tcp://0.0.0.0:46658", example.NewCounterApplication())
```

where the CounterApplication is defined in `example/golang/counter.go`, and implements the TMSP application interface.

In another window, start the `tmsp console`:

```
> echo hello
> info
> get_hash
> info
> append_tx abc
> get_hash
> set_option serial on
> append_tx def
> append_tx 0x01
> append_tx 0x02
> append_tx 0x05
> info
> commit
> info
```

Now, this is a very simple application, but between the counter and the dummy, its easy to see how you can build out arbitrary application states on top of the TMSP. Indeed, `erisdb` of Eris Industries can run atop TMSP now, bringing with it ethereum like accounts, the ethereum virtual machine, and eris's permissioning scheme and native contracts extensions.

But the ultimate flexibility comes from being able to write the application easily in any language. 

We have implemented the counter app in Python:

```
cd example/python
python app.py
```

(you'll have to kill the other counter application process). 
In another window, run the console and those previous tmsp commands. 
You should get the same results as for the golang version.

Want to write the counter app in your favorite language?! We'd be happy to accept the pull request.

Before continuing, please kill the `python app.py` process.

TODO: write it in Javascript

# Tendermint

Now that we've seen how TMSP works, and even played with a few applications using the `tmsp` tool,
let's run an actual Tendermint node.

When running a live application, a Tendermint node takes the place of the `tmsp` tool by sending TMSP requests
to the application: `append_tx` when transactions are received by the mempool, `commit` when the consensus protocol commits a new block, and so on.

Installing Tendermint is easy:

```
go get github.com/tendermint/tendermint/cmd/tendermint
```

If you already have Tendermint installed, then you can either set a new `$GOPATH` and run the previous command,
or else fetch and checkout the latest master branch in `$GOPATH/src/github.com/tendermint/tendermint`,
and from that directory run

```
go get ./cmd/tendermint
go install ./cmd/tendermint
```

To initialize a genesis and validator key in `~/.tendermint`, run

```
tendermint init
```

You can change the directory by setting the `$TMROOT` environment variable.

Now,

```
tendermint node
```

You should see `Failed to connect to proxy for mempool: dial tcp 127.0.0.1:46658: getsockopt: connection refused`

That's because we don't have an application process running, and Tendermint will only run if there's an application it can speak TMSP with.

So lets start the dummy app,

```
dummy
```

and in another window, start Tendermint:

```
tendermint node
```

After a few seconds you should see blocks start streaming in!

Now you can send transactions through the Tendermint RPC server with curl requests, or from your browser:

```
curl http://localhost:46657/broadcast_tx?tx=\"abcd\"
```

For handling responses, we recommend you [install the `jq` tool](https://stedolan.github.io/jq/) to pretty print the JSON

We can see the chain's status at the `/status` end-point:

```
curl http://localhost:46657/status |  jq .
```

and the `latest_app_hash` in particular:

```
curl http://localhost:46657/status |  jq . | grep app_hash
```

visit http://localhost:46657 in your browser to see the other endpoints.


# Deploy a Tendermint Testnet

Now that we've run a single Tendermint node with one validator and a couple applications, 
let's deploy a testnet to run our application with four validators.

For this part of the tutorial, we assume you have an account at digital ocean and are willing to 
pay to start some new droplets to run your nodes. You can of course stop and destroy them at any time.

To deploy a testnet, use the `mintnet` tool:

```
go get github.com/tendermint/mintnet
```
