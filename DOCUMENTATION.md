# HuntingBehaviour API Reference
Generated: 2026-05-20

an addon to create hunting behaviour on a node

## Class: TopDownHuntingBehaviour
**Inherits:** [State](git@github.com:ChillCube/State/blob/main/DOCUMENTATION.md)


### ⚙️ Inspector Variables (Exported)
| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| **prey** | `Node2D` | `-` | The target node this enemy will hunt |
| **view_radius** | `float` | `300.0` | Maximum distance at which the enemy can see the prey |
| **view_angle** | `float` | `360.0` | Field-of-view cone in degrees (360 = omnidirectional) |
| **speed** | `float` | `100.0` | Movement speed passed to the TopDownMovement component |
| **max_sight_chain** | `int` | `3` | Number of ray-cast waypoints built when sight is lost (higher = smarter pathing around obstacles) |
| **enable_wander_off** | `bool` | `true` | If true, enemy wanders briefly before returning to its previous state when it loses sight |
| **wander_duration** | `float` | `1.5` | How many seconds the enemy continues in the last-known direction before giving up |

### 🛠️ Methods
| Method | Arguments | Returns | Description |
| :--- | :--- | :--- | :--- |
| **can_see_player()** | - | `bool` |  Returns true if prey is within view_radius, inside the view_angle cone, and not blocked by geometry |
| **process_behaviour()** | - | `void` |  Each frame: pursue prey when visible, follow waypoints when sight is lost, wander off when chain exhausted |

---

