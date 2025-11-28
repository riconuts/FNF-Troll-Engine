package funkin.states.options;

interface IBindsMenu<T:Keybind> {
    var changedBind:(String, Int, T) -> Void;
}