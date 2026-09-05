extends SceneTree

const ResultContract = preload("res://scripts/core/result_contract.gd")
const SnapshotContract = preload("res://scripts/core/snapshot_contract.gd")

func _init() -> void:
    var success := ResultContract.ok({"amount": 2}, "done")
    assert(success == {"ok": true, "reason": "done", "changed": true, "data": {"amount": 2}})
    var failure := ResultContract.fail("inventory_full")
    assert(failure == {"ok": false, "reason": "inventory_full", "changed": false, "data": {}})
    assert(ResultContract.is_valid(success))
    assert(not ResultContract.is_valid({"ok": true}))
    var source := {"nested": {"value": 1}}
    var copy := SnapshotContract.copy(source)
    copy["nested"]["value"] = 9
    assert(source["nested"]["value"] == 1)
    assert(SnapshotContract.require_keys({"a": 1, "b": 2}, ["a", "b"]))
    assert(not SnapshotContract.require_keys({"a": 1}, ["a", "b"]))
    print("ARCHITECTURE_CONTRACT_REGRESSION_OK")
    quit()
