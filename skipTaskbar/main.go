package main

import (
	"fmt"

	"github.com/jezek/xgb"
	"github.com/jezek/xgb/xproto"
	"go.i3wm.org/i3/v4"
)

func xcbChangePropertyAtom(window xproto.Window, property xproto.Atom, atom xproto.Atom, add bool) {
	cookie := xproto.GetProperty(conn, false, window, property, xproto.GetPropertyTypeAny, 0, 4096)
	reply, err := cookie.Reply()
	if err != nil {
		panic(err)
	}

	fmt.Println("Got", reply.Value)

	var atoms []xproto.Atom
	if reply.ValueLen > 0 {
		atoms = make([]xproto.Atom, reply.ValueLen) // Each atom is 4 bytes (uint32)
		for i := 0; i < int(reply.ValueLen); i++ {
			atoms[i] = xproto.Atom(xgb.Get32(reply.Value[i*4:]))
		}
	}

	var values []byte
	for _, a := range atoms {
		if a != atom {
			c := make([]byte, 4)
			xgb.Put32(c, uint32(a))
			values = append(values, c...)
		}
	}
	if add {
		c := make([]byte, 4)
		xgb.Put32(c, uint32(atom))
		values = append(values, c...)
	}

	fmt.Println(byte(atom), values, atoms)

	err = xproto.ChangePropertyChecked(conn, xproto.PropModeReplace, window, property, xproto.AtomAtom, 32, uint32(len(values)/4), values).Check()
	if err != nil {
		panic(err)
	}
}

func addAtom(name string) xproto.Atom {
	cookie := xproto.InternAtom(conn, false, uint16(len(name)), name)
	reply, err := cookie.Reply()
	if err != nil {
		return 0
	}

	return reply.Atom
}

var (
	conn = func() *xgb.Conn {
		conn, err := xgb.NewConn()
		if err != nil {
			panic(err)
		}
		return conn
	}()
	stateAtom   = addAtom("_NET_WM_STATE")
	taskbarAtom = addAtom("_NET_WM_STATE_SKIP_TASKBAR")
)

func updateAll(n *i3.Node, target string) {
	if n.Window > 0 {
		add := target != "" && n.WindowProperties.Class != target
		go xcbChangePropertyAtom(xproto.Window(n.Window), stateAtom, taskbarAtom, add)
	}

	for _, child := range n.Nodes {
		updateAll(child, target)
	}
	for _, child := range n.FloatingNodes {
		updateAll(child, target)
	}
}

func main() {
	defer conn.Sync()
	defer conn.Close()

	eventReceiver := i3.Subscribe(i3.WorkspaceEventType, i3.WindowEventType)

	for eventReceiver.Next() {
		t, err := i3.GetTree()
		if err != nil {
			panic(err)
		}
		target := ""

		switch event := eventReceiver.Event().(type) {
		case *i3.WindowEvent:
			if event.Change == "focus" {
				fmt.Println("Focus window:", event.Container.WindowProperties.Class)
			}
			target = event.Container.WindowProperties.Class
		case *i3.WorkspaceEvent:
			node := t.Root.FindFocused(func(node *i3.Node) bool {
				return node.Window != 0
			})
			if node != nil {
				continue
			}
		}
		updateAll(t.Root, target)
	}
}
